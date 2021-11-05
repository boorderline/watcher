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
      Log.info { "Starting watch for #{@config.name}" }

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
      values = @config.target.values.nil? ? nil : YAML.dump(@config.target.values)

      release_values = @helm.get_revision_values(
        release: @config.target.name,
        namespace: @config.target.namespace,
      )

      # TODO: Check additional rules. Probably we need to define them.

      if (latest_version != latest_chart.version) || (!@config.target.values.nil? && (release_values != @config.target.values))
        Log.info { "Trigger new release for #{@config.name}" }

        @helm.deploy(
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

        Log.info { "Successfully  deployed a new release for #{@config.name}" }
      end
    rescue ex
      Log.error { ex.message }
    end
  end
end
