require 'rest-client'

module Wires
  class WiresTracking
    def self.create_flow(tracking_number: nil, function: nil)
      tracking_number = tracking_number.nil? ? generate_tracking_number : 'T' + tracking_number
      if tracking?(tracking_number)
        flow_message = { wires_tracking_number: tracking_number,
                         flow_function: function }
        message_to_server('/wires_create_flow', flow_message)
      end
      tracking_number
    end

    def self.add_reference_to_flow(tracking_number, reference_number)
      return unless tracking?(tracking_number)
      reference_message = { wires_tracking_number: tracking_number,
                            reference_number: reference_number }
      message_to_server('/wires_add_reference', reference_message)
    end

    def self.check_point(tracking_number)
      return if tracking_number.nil?
      return unless tracking?(tracking_number)
      caller_info = caller_locations(1..1).first
      message = { wires_tracking_number: tracking_number,
                  method_name: caller_info.label,
                  line_number: caller_info.lineno,
                  class_name: caller_info.path.split('/').last,
                  server: Wires.configuration.server_name,
                  check_in_timestamp: Time.now.utc }
      message_to_server('/wires_create_check_point', message)
    end

    private_class_method

    def self.generate_tracking_number
      num = Random.rand(1000)
      timestamp = Time.now.utc.to_i.to_s
      frequency = Wires.configuration.frequency
      (num % frequency).zero? ? 'T' + timestamp + num.to_s : timestamp + num.to_s
    end

    def self.tracking?(tracking_number)
      tracking_number[0] == 'T'
    end

    def self.message_to_server(url, message)
      begin
        RestClient.post(Wires.configuration.wires_server_url + url, message: message.to_json)
      rescue => e
        puts 'Pretending to send message to wires server.'
      end
    end
  end
end