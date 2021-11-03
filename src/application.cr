require "./config"
require "./helm"

module Watcher
  class Application
    Log = ::Log.for(self)

    getter config : Watcher::Config::App

    def initialize(@config)
      @helm = Watcher::Helm::Client.new
    end

    def run
      Log.info { "Starting watcher for: #{@config.name}" }

      loop do
        begin
          latest_chart = @helm.get_latest_chart(
            chart: @config.source.chart,
            repo: @config.source.repository,
            username: @config.source.repository_username,
            password: @config.source.repository_password,
          )

          # Check if deployment exists
          latest_release = @helm.list_releases(@config.target.namespace)
            .find { |r| r.name == @config.target.name }
          latest_version = latest_release.nil? ? "" : latest_release.extract_chart_version(@config.source.chart)

          # TODO: Check additional rules. Probably we need to define them.

          if latest_version != latest_chart.version
            Log.info { "New release for #{@config.target.name} at version #{latest_chart.version}" }

            # TODO: Also check if the values have changed and trigger a new release if so ...
            values = @config.target.values.nil? ? nil : YAML.dump(@config.target.values)

            result = @helm.deploy(
              release: @config.target.name,
              chart: @config.source.chart,
              version: latest_chart.version,
              repo: @config.source.repository,
              username: @config.source.repository_username,
              password: @config.source.repository_password,
              namespace: @config.target.namespace,
              create_namespace: @config.target.create_namespace,
              values: values,
            )

            Log.info { "Successfully deployed #{@config.target.name} at revision #{result.version}" }
          end
        rescue ex
          Log.error { ex.message }
        end

        interval = Time::Span.new(seconds: @config.scrape.interval)
        Log.info { "Next iteration in #{interval}" }
        sleep(interval)
      end
    end
  end
end