module AppName

  def app_name
    #tells us which of main/cs/acc we are in.
    current_app = Rails.application.config.session_options[:key].sub(/^_/,'').sub(/_session/,'')
    case current_app
    when "autobrain"
      :main
    when "device-communication-service"
      :cs
    when "calibration"
      :acc
    else
      nil
    end
  end

end
