require "log"
require "http/server"
require "option_parser"

require "./config"
require "./helm"

module Watcher
  VERSION = "0.1.0"

  class Application
    Log = ::Log.for(self)

    getter config : Watcher::Config::App

    def initialize(@config)
    end

    def run
      Log.info { "Starting watcher for: #{@config.name}" }
      helm = Watcher::Helm::Client.new

      loop do
        begin
          latest_entry = helm.get_latest_chart(
            chart: @config.source.chart,
            repo: @config.source.repository,
            username: @config.source.repository_username,
            password: @config.source.repository_password,
          )

          # Check if deployment exists
          latest_release = helm.list_releases(@config.target.namespace)
            .find { |r| r.name == @config.target.name }
          latest_version = latest_release.nil? ? "" : latest_release.extract_chart_version(@config.source.chart)

          if latest_version != latest_entry.version
            Log.info { "New release for #{@config.target.name} at version #{latest_entry.version}" }

            # TODO: Check additional rules. Probably we need to define them.

            result = helm.deploy(
              release: @config.target.name,
              chart: @config.source.chart,
              version: latest_entry.version,
              repo: @config.source.repository,
              username: @config.source.repository_username,
              password: @config.source.repository_password,
              namespace: @config.target.namespace,
              create_namespace: @config.target.create_namespace,
            )

            Log.info { "Successfully deployed #{@config.target.name} at revision #{result.version}" }
          end

          # TODO: Also check if the values have changed and trigger a new release if so ...
        rescue ex
          Log.error { ex.message }
        end

        interval = Time::Span.new(seconds: @config.scrape.interval)
        Log.info { "Next iteration in #{interval}" }
        sleep interval
      end
    end
  end
end

begin
  Log.setup

  config_dir = nil
  OptionParser.parse do |parser|
    parser.banner = "Usage: watcher [args]"

    parser.on("--config-dir=DIR", "-d DIR", "Configurations directory") { |dir| config_dir = dir }
    parser.on("--help", "-h", "Display this help") do
      puts parser
      exit
    end

    parser.invalid_option { |flag| raise "Unkown flag: #{flag}" }
  end

  if config_dir.nil?
    raise "Missing configuration directory!"
  end

  if !Dir.exists?(config_dir.as(String))
    raise "Directory #{config_dir} doesn't exist!"
  end

  apps = Watcher::Config.load_from_dir(config_dir.as(String))
  Log.info { "Loaded #{apps.size} configurations from #{config_dir}" }

  if apps.empty?
    raise "Did dot find any configurations. Exiting..."
  end

  apps.each { |config| spawn Watcher::Application.new(config).run }

  # ... Starting a webserver to display some info.
  server = HTTP::Server.new do |context|
    context.response.content_type = "text/plain"
    context.response.print "Hello world!"
  end

  address = server.bind_tcp "0.0.0.0", 8080
  puts "Listening on http://#{address}"
  server.listen
rescue ex
  STDERR.puts "ERROR: #{ex.message}"
  exit(1)
end
