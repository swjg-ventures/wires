# Message Tracking Service
#
#   This is the CS-app component of the Wires system. Wires tracks messages to and from the devices. The
#   use case is to determine points of failure across the system of apps and within them. Two types of events are
#   recorded: checkpoints and payload accesses. Information is coordinated using tracking numbers.
#
#   Devices can be set as 'tracked' on the Devices part of the Worker UI on main. Messages to and from the device will
#   be tracked up to the expiration time. The tracking information is posted into a Kafka topic that is indexed
#   and viewable on Kibana. On a Kibana dashboard, a break in the wire will be indicated by counting the checkpoints
#   per message and finding a count less than the total number of checkpoints. Services using payload are indicated by
#   payload access events. To avoid performance problems, there is a configurable limit on the maximum number of devices
#   that can be tracked.
#
#   Messages will also be automatically tracked according to a given probability that is set in the config, so a
#   value of 0.01 will track approximately 1 percent of messages.
#
#   Checkpoints are specific places in the app that log the progress of a tracked message. The checkpoints can be used
#   to figure out if the wire is connected or not. For instance, if a message hits fewer than the total number of
#   checkpoints through the system of apps it is either still in transit or lost. Maybe the message hit the checkpoint
#   for sending to ACC from CS but it did not hit the checkpoint for incoming OBD on main. This is data that can be
#   analyzed on Kibana or another analysis app to automatically notify us of data flow problems.
#
#   Checkpoints located at:
#     Incoming - IncomingObdMessagesController  handle_udp_obd_message
#     Incoming - IncomingObdMessagesController  send_sms_obd_for_processing
#     Incoming - Payload                        initialize
#     Incoming - SendObdMessageToAccAppWorker   send_obd_message_to_acc_app
#     Outgoing - MessageToCarController         handle_udp
#     Outgoing - MessageToCarController         handle_sms
#     Outgoing - MessageToCarWorker             handle_udp
#     Outgoing - MessageToCarWorker             handle_sms


class MessageTrackingService

  include MessageTrackingServiceHelper
  include AppName

  attr_reader :message_hash, :tracking_number, :checkpoint_hash, :message_to_log

  def initialize message
    @message_hash = prepare_message_hash message
    @tracking_number = message_hash[:tracking_number] # get tracking number if it was assigned by an earlier checkpoint
    @last_payload_access = message_hash[:last_payload_access]
    @checkpoint_hash = message_hash[:checkpoint_hash] || message_hash[:creator] || caller[1]
    if @checkpoint_hash.class == String
      @checkpoint_hash = parse_caller_trace_line @checkpoint_hash
    end
  end

  def prepare_message_hash message
    case message
    when Array
      { raw_obd_data: '$$' + message.join(',') + '##' }
    when String
      { raw_obd_data: message }
    when ActionController::Parameters
      message.permit!.to_h
    when Hash
      message
    else raise TypeError, 'Unknown input type for new MessageTrackingService. Expected Array, String, Hash or ActionController::Parameters'
    end
  end

  # Called when a tracked method in payload is accessed by another object, such as a service. Logs what was accessed as
  # well as the accessing object's file, method, and line number. Helps track the nonlinear data flow through the app
  # as a payload is absorbed into the feature services.

  def process_payload_access method_called, method_caller
    @message_to_log = payload_access_log_message( method_called, method_caller )
    write message_to_log
    self
  end

  # TODO handle outgoing messages originating on CS

  # Called at a point where a tracked outgoing message is passing through, in order to add tracking information and
  # log the progress of a message through the system of apps

  def process_checkpoint_outgoing
    return self unless tracking_number
    @message_to_log = checkpoint_log_message( 'outgoing' )
    write message_to_log
    self
  end

  # Called at a point where a tracked incoming message is passing through, in order to log the progress of a message
  # through the system of apps

  def process_checkpoint_incoming
    return self unless incoming_tracked? uid
    if tracking_number.nil?
      raise 'tracking_number should have a value!'
    end
    @message_to_log = checkpoint_log_message( 'incoming' )
    write message_to_log
    self
  end

  def process_payload_creation
    return self unless has_unexpired_tracker? uid
    @tracking_number = new_tracking_number unless tracking_number
    case app_name
    when :cs
      direction = 'incoming'
    when :acc
      direction = 'incoming'
    when :main
      direction = 'outgoing'
    end
    @message_to_log = checkpoint_log_message( direction )
    write message_to_log
    self
  end

  def tracking_number_hash
    tracking_number ? { tracking_number: tracking_number } : {}
  end

  private

  def checkpoint_log_message direction
    raise TypeError, 'Argument "direction" must be "incoming" or "outgoing"' if ['incoming', 'outgoing'].exclude? direction
    {
        checkpoint_hash:      checkpoint_hash,
        uid:                  uid.to_i,
        direction:            direction,
        parsed_stack_trace:   parse_callers,
        timestamp:            Time.now.utc,
        short_message:        message_hash,
        tracking_number:      tracking_number,
        last_payload_access:  message_hash[:last_payload_access]
    }.merge( elastic_search_info ).merge( app_info )
  end

  def payload_access_log_message method_called, payload_caller
    parsed_trace = parse_caller_trace_line( payload_caller )
    return nil if parsed_trace.nil?
    case app_name
    when :main
      uid_to_log = message_hash[:obd_data_in_hash]['UID']
    when :cs
      uid_to_log = message_hash[:uid]
    when :acc
      uid_to_log = nil
    end
    {
        uid:                  uid_to_log,
        tracking_number:      message_hash[:tracking_number],
        obd_reference_number: message_hash[:obd_reference_number],
        parsed_stack_trace:   parse_callers,
        location:             location,
        direction:            'incoming', #payloads are only for incoming messages
        caller:               parsed_trace,
        called:               method_called,
        timestamp:            Time.now.utc,
        last_payload_access:  message_hash[:last_payload_access]
    }.merge( elastic_search_info ).merge( app_info )
  end

  def location
    return { lat: 0.0, lon: 0.0 } unless message_hash[:obd_data_in_hash]
    {
        lat: message_hash[:obd_data_in_hash]['LT'].to_f,
        lon: message_hash[:obd_data_in_hash]['LN'].to_f
    } #TODO type as geo_point in logstash template to enable map visualization
  end

end
