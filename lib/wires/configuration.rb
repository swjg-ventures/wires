module Wires
  class Configuration
    attr_accessor :wires_server_url, :server_name, :frequency

    def initialize
      @wires_server_url = nil
      @server_name = nil
      @frequency = nil
    end
  end
end