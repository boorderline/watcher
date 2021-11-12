require "./config"
require "./helm"

module Watcher
  class Application
    getter config : Watcher::Config::App

    def initialize(@config)
      @helm = Watcher::Helm::Client.new
      @log = Log.for(@config.name)
    end

    def run
      @log.info { "Checking application for changes..." }

      chart = @helm.get_chart(
        chart: @config.source.chart,
        version: @config.source.version,
        allow_prereleases: @config.source.allow_prereleases,
        repo: @config.source.repository,
        username: @config.source.repository_username,
        password: @config.source.repository_password,
      )

      release = @helm.list_releases(@config.target.namespace).find { |r| r.name == @config.target.name }
      release_version = release.nil? ? nil : release.extract_chart_version(@config.source.chart)
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

        @log.info { "Release: #{@config.target.name} at revision #{result.revision} in namespace '#{@config.target.namespace}'" }
      end
    rescue ex
      @log.error { ex.message }
    end
  end
end
