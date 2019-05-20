# -*- encoding: utf-8 -*-
# stub: wires 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "wires".freeze
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "TODO: Set to 'http://mygemserver.com'" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Zheng Fu".freeze]
  s.bindir = "exe".freeze
  s.date = "2019-03-13"
  s.description = "Autobrain Wires Tracking gem.".freeze
  s.email = ["z.fu@myautobrain.com".freeze]
  s.files = [".gitignore".freeze, ".ruby-version".freeze, "Gemfile".freeze, "Gemfile.lock".freeze, "README.md".freeze, "Rakefile".freeze, "bin/console".freeze, "bin/setup".freeze, "lib/wires.rb".freeze, "lib/wires/configuration.rb".freeze, "lib/wires/version.rb".freeze, "lib/wires/wires_tracking.rb".freeze, "wires.gemspec".freeze, "wires_old/README.md".freeze, "wires_old/lib/wires_tracking.rb".freeze, "wires_old/lib/wires_tracking/app_name.rb".freeze, "wires_old/lib/wires_tracking/message_tracking_service.rb".freeze, "wires_old/lib/wires_tracking/message_tracking_service_helper.rb".freeze, "wires_old/lib/wires_tracking/payload_tracking_interceptor.rb".freeze, "wires_old/wires_tracking-0.0.13.gem".freeze, "wires_old/wires_tracking-0.0.14.gem".freeze, "wires_old/wires_tracking.gemspec".freeze]
  s.homepage = "https://github.com/swjg-ventures/wires".freeze
  s.rubygems_version = "2.5.2".freeze
  s.summary = "Autobrain Wires Tracking gem.".freeze

  s.installed_by_version = "2.5.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>.freeze, ["~> 1.16"])
      s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
      s.add_development_dependency(%q<minitest>.freeze, ["~> 5.0"])
      s.add_runtime_dependency(%q<rest-client>.freeze, [">= 0"])
    else
      s.add_dependency(%q<bundler>.freeze, ["~> 1.16"])
      s.add_dependency(%q<rake>.freeze, ["~> 10.0"])
      s.add_dependency(%q<minitest>.freeze, ["~> 5.0"])
      s.add_dependency(%q<rest-client>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<bundler>.freeze, ["~> 1.16"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.0"])
    s.add_dependency(%q<minitest>.freeze, ["~> 5.0"])
    s.add_dependency(%q<rest-client>.freeze, [">= 0"])
  end
end
