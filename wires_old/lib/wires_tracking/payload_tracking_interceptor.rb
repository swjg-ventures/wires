# Payload Tracking Interceptor
#
#   Mixes into the PayloadService and provides capabilities for tracking messages. See: MessageTrackingService

module PayloadTrackingInterceptor

  include AppName

  TRACKING_SOURCE_EXCLUSION_PATTERNS = /payload_service\.rb|payload\.rb|payload_tracking_interceptor\.rb|add_tracking_to_methods/

  attr_reader :last_payload_access

  def self.included(class_that_included_interceptor)
    class_that_included_interceptor.extend(ClassTracking)
  end



  def tracking_hash
    case app_name
    when :main
      simple_obd_data_in_hash ||= JSON.parse(obd_data_in_hash.to_json) # convert big decimal to primitive
      simple_uid = nil
      simple_cs_timestamp = cs_timestamp
    when :cs
      simple_obd_data_in_hash = {}
      simple_uid = uid
      simple_cs_timestamp = nil
    when :acc
      simple_obd_data_in_hash = {}
      simple_uid= nil
      simple_cs_timestamp = cs_timestamp
    end
    @last_payload_access ||= nil
    {
        uid:                    simple_uid,
        obd_reference_number:   obd_reference_number,
        obd_data_in_hash:       simple_obd_data_in_hash, # TODO refactor CS to memoize payload's obd_data_in_hash
        bridge_timestamp:       bridge_timestamp,
        cs_timestamp:           simple_cs_timestamp,
        tracking_number:        tracking_number,
        raw_obd_data:           raw_obd_data,
        last_payload_access:    last_payload_access
    }
  end

  # Handles tracking checkpoint for payload creation

  def handle_tracking options = {}
    @tracking_number ||= options[:tracking_number]
    @last_payload_access ||= options[:last_payload_access]
    return unless tracking_number if app_name == :main
    creator = caller[1]
    tracking_service = MessageTrackingService
                        .new(tracking_hash.merge(creator: creator))
                        .process_payload_creation
    @tracking_number = tracking_service.tracking_number
    begin
      @last_payload_access = tracking_service.message_to_log.slice :checkpoint_hash, :timestamp
    rescue
      @last_payload_access = nil
    end
  end

  # Extending payload with this module allows calling :add_tracking_to_methods during class loading

  module ClassTracking

    def add_tracking_to_methods method_names
      method_names.each do |method_name|                  # For every tracked method
        unbound_method = instance_method(method_name)     #   unbind original method
        define_method(method_name) do |*args, &block|     #   redefine method:
          log_if_tracked method_name               #     add logging before original code
          unbound_method.bind(self).(*args, &block)       #     put the method's original code back in
        end
      end
    end

  end

  def log_if_tracked method_name
    if self.tracking_number || ( Settings.message_tracking_all && Rails.env.development? )
      method_caller = caller[1]
      unless TRACKING_SOURCE_EXCLUSION_PATTERNS.match(method_caller)    # to avoid loops
        @last_payload_access =  MessageTrackingService
                              .new(self.tracking_hash)
                              .process_payload_access(method_name, method_caller)
                              .message_to_log.slice :caller, :timestamp
      end
    end
  end


end
