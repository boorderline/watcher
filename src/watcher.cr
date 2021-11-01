require "log"
require "uri"
require "http/client"
require "http/server"
require "option_parser"

require "./config"
require "./helm/*"

module Watcher
  VERSION = "0.1.0"

  class Application
    Log = ::Log.for(self)

    getter config : Watcher::Config::App

    def initialize(@config)
    end

    def run
      helm = Watcher::Helm::Client.new(@config.target.namespace)

      loop do
        Log.info { "Starting watcher for: #{@config.name}" }

        # Managing custom and additional headers
        headers = HTTP::Headers{
          "User-Agent" => "BoordCD/#{Watcher::VERSION}",
        }

        unless @config.scrape.headers.nil?
          headers.merge!(@config.scrape.headers.as(Hash(String, String)))
        end

        begin
          repository = URI.parse(@config.source.repository)
            .resolve("index.yaml")

          HTTP::Client.get(repository, headers) do |response|
            raise "Response not OK: #{response.status_code}" unless response.success?

            body = response.body_io.gets_to_end
            manifest = Watcher::Helm::Manifest.from_yaml(body)

            if !manifest.entries.has_key?(@config.source.chart)
              Log.warn { "Chart #{@config.source.chart} not found!" }
              next
            end

            if manifest.entries[@config.source.chart].empty?
              Log.warn { "Chart #{@config.source.chart} has no entries!" }
              next
            end

            latest_entry = manifest.entries[@config.source.chart]
              .sort { |a, b| b.created <=> a.created }
              .first

            # Check if deployment exists
            latest_release = helm.list_releases.find { |r| r.name == @config.target.name }
            latest_version = latest_release.nil? ? "" : latest_release.extract_chart_version(@config.source.chart)

            if latest_version != latest_entry.version
              Log.info { "New release for #{@config.target.name} at version #{latest_entry.version}" }

              # TODO: Check additional rules. Probably we need to define them.

              result = helm.deploy(
                name: @config.target.name,
                chart: @config.source.chart,
                repository: @config.source.repository,
                version: latest_entry.version,
              )

              Log.info { "Successfully deployed #{@config.target.name} at revision #{result.version}" }
            end
          end
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
  Log.setup_from_env(
    default_sources: "watcher.*"
  )

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

  raise "Missing configuration directory!" if config_dir.nil?
  raise "Directory #{config_dir} doesn't exist!" if !Dir.exists?(config_dir.as(String))
  Log.debug { "Configuration directory: #{config_dir}" }

  # Load all application configurations from the config directory...
  apps = Watcher::Config.load_from_dir(config_dir.as(String))
  Log.debug { "Total configurations loaded: #{apps.size}" }
  raise "Did dot find any configurations. Exiting..." if apps.empty?

  # TODO: Check max apps limit!

  # Otherwise we start a watcher for each configuration on separate fiber...
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
