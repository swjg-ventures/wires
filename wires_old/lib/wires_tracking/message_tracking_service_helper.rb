module MessageTrackingServiceHelper

  private

  def write message_to_log
    standardized_log = standardize_log_message message_to_log
    if Rails.env.test? || Rails.env.development?
      Activity.create!( data: standardized_log.to_json )
    else
      wires_logger.info standardized_log.to_json
    end
  end

  def wires_logger
    @@_wires_logger ||= setup_logger
  end

  def setup_logger
    logger = Logger.new Settings.wires_log_path,
                        Settings.wires_log_aged_file_limit,
                        Settings.wires_log_size_before_age
    logger.formatter = proc { |_,_,_,msg| msg.to_s + "\n"}
    logger
  end

  def new_tracking_number
    "#{AwsMetadataService.instance_id} #{Time.now.utc.iso8601} #{SecureRandom.base64(9)}"
  end

  # Called at the point of origin of outgoing messages to decide if tracking is required

  def incoming_tracked? uid
    @_incoming_tracked ||=  tracking_number || randomly_chosen_for_tracking? ||
                            has_unexpired_tracker?(uid) || Settings.message_tracking_all
  end

  def outgoing_tracked? uid
    @_outgoing_tracked ||= randomly_chosen_for_tracking? || has_unexpired_tracker?(uid)
  end

  def has_unexpired_tracker? uid
    tracker = DeviceMessageTracker.where(uid: uid).first
    tracker && !tracker.expired?
  end

  def randomly_chosen_for_tracking?
    Rails.env.test? ? false : rand < Settings.message_tracking_probability
  end

  # Specify the instance and environment of the app that processed the message

  def app_info
    @@_app_info ||= {
        instance_id:  AwsMetadataService.instance_id,
        environment:  Rails.env
    }
  end

  def parse_caller_trace_line caller_line
    caller_pattern = /\/([a-z_]*\.rb):(.*):in.*`(.*)'/ # matches file, line, method
    caller_match = caller_pattern.match(caller_line)
    return nil if caller_match.nil?
    file, line, method = caller_match.captures
    {
        file:   file,
        line:   line,
        method: method
    }
  end

  def repo_name
    @@repo_name ||= Rails.root.to_s.split('/').last
  end

  # Elastic search info is what is needed by elastic search, kibana, and logstash to determine where the log is stored
  # and how it is categorized. It adds the environment, log type, and repo name that the message originated from.

  def elastic_search_info
    @@elastic_search_info ||= {
        tags: [Rails.env],
        type: Settings.wires_elastic_search_type,
        source: repo_name
    }
  end

  def uid
    @_uid ||= begin
                message_hash[:uid] || ( message_hash[:raw_obd_data] && uid_from_raw_obd( message_hash[:raw_obd_data] ) ) ||
                message_hash['UID'] || (message_hash[:obd_data_in_hash] && message_hash[:obd_data_in_hash]['UID'])
              end.to_i
  end

  def uid_from_raw_obd message
    /^\$\$(\d+),/.match(message.strip).captures[0]
  end

  # Returns all of the callers when a message is originated for sending. Gives us some idea of the chain of events
  # leading up to the creation of the message.

  def parse_callers
    caller.map do |caller|
      parse_caller_trace_line caller
    end.reject do |caller|
      caller.nil? || OUTGOING_CALLER_EXCLUSIONS.include?(caller[:file])   # filter out blanks and calls from third-party infrastructure
    end
  end

  def standardize_log_message hash
    #This method buffers empty fields with nil
    empty_hash = Hash[MESSAGE_FIELDS.map{|field| [field, nil]}]
    empty_hash.merge(hash)
  end
  # The caller trace for tracked outgoing messages will exclude files with these names. These files are in stack traces
  # but not part of our app. This is for keeping the focus on the chain of events within our own code instead of the
  # infrastructure of Rails, etc.
  MESSAGE_FIELDS = [
        :checkpoint_hash,
        :uid,
        :direction,
        :parsed_stack_trace,
        :timestamp,
        :short_message,
        :tracking_number,
        :last_payload_access,
        :obd_reference_number,
        :location,
        :caller,
        :called,
        :tags,       #elastic_search_info
        :type,
        :source,
        :instance_id,  #app_info
        :environment,
  ]
  OUTGOING_CALLER_EXCLUSIONS = [
    :active_job,
    :agent,
    :agent_hooks,
    :base,
    :basic_implicit_render,
    :benchmark,
    :browser_monitoring,
    :callbacks,
    :catch_json_parse_errors,
    :chain,
    :clear_locks,
    :cmdline,
    :command,
    :conditional_get,
    :config,
    :configuration,
    :connection_wrapper,
    :controller,
    :controller_instrumentation,
    :controller_runtime,
    :cookies,
    :daemons,
    :database_statements,
    :debug_exceptions,
    :delayed_job_instrumentation,
    :developer_mode,
    :dirty,
    :engine,
    :enqueuing,
    :error_notifier,
    :etag,
    :exec,
    :execution,
    :execution_wrapper,
    :executor,
    :head,
    :id,
    :implicit_render,
    :instrumentation,
    :instrumenter,
    :lifecycle,
    :line_filtering,
    :local_cache_middleware,
    :logger,
    :logging,
    :makara_abstract_adapter,
    :manager,
    :message_sending,
    :message_tracking_interceptor,
    :message_tracking_service,
    :metal,
    :method_override,
    :method_tracer,
    :middleware,
    :middleware_tracing,
    :migration,
    :minitest,
    :minitest_plugin,
    :notifications,
    :params_wrapper,
    :performable_method,
    :persistence,
    :plugin,
    :pool,
    :processor,
    :proxy,
    :quiet_assets,
    :rails,
    :railtie,
    :reloader,
    :remote_ip,
    :rendering,
    :reporters,
    :request_id,
    :rescue,
    :route_set,
    :router,
    :runtime,
    :seamless_database_pool,
    :sendfile,
    :server,
    :show_exceptions,
    :sidekiq,
    :sidekiq_adapter,
    :ssl,
    :static,
    :tagged_logging,
    :test,
    :test_case,
    :test_helpers,
    :thread_pool,
    :timeout,
    :timestamp,
    :trace,
    :traced_call,
    :transaction,
    :transactions,
    :translation,
    :user_feedback,
    :user_informer,
    :util,
    :validations,
    :with_request,
    :worker,
  ].map {|e| (e.to_s + '.rb').freeze}.freeze

end
