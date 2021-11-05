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
      Log.debug { "Starting watch for #{@config.name}" }

      chart = @helm.get_latest_chart(
        chart: @config.source.chart,
        repo: @config.source.repository,
        username: @config.source.repository_username,
        password: @config.source.repository_password,
      )

      if !@config.source.prerelease && chart.prerelease?
        Log.warn { "Ignoring pre-release version #{chart.version} for chart #{chart.name}" }
        return
      end

      release = @helm.list_releases(@config.target.namespace).find { |r| r.name == @config.target.name }
      release_version = release.nil? ? "" : release.extract_chart_version(@config.source.chart)
      release_values = release.nil? ? nil : @helm.get_release_values(@config.target.name, @config.target.namespace)

      if (release_version != chart.version) || (release_values != @config.target.values)
        result = @helm.deploy(
          release: @config.target.name,
          chart: @config.source.chart,
          version: chart.version,
          repo: @config.source.repository,
          username: @config.source.repository_username,
          password: @config.source.repository_password,
          namespace: @config.target.namespace,
          create_namespace: @config.target.create_namespace,
          values: @config.target.values.nil? ? nil : YAML.dump(@config.target.values),
          reset_values: @config.target.values.nil?
        )

        Log.info { "Release '#{@config.target.name}' in namespace #{@config.target.namespace} is at revision #{result.version}" }
      end
    rescue ex
      Log.error { ex.message }
    end
  end
end
