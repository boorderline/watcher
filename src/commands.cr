require "./config"
require "./helm"

module Watcher
  class Command::Update
    # Application configuration object
    getter config : Watcher::Config

    def initialize(@config)
      @helm = Watcher::Helm::Client.new
      @log = Log.for(@config.name)
    end

    # Runs the update process using the application configuration
    def run
      @log.info { "Checking for changes..." }

      chart = self.get_chart

      release = @helm.list_releases(@config.target.namespace).find { |r| r.name == @config.target.name }
      release_version = release.nil? ? nil : release.extract_chart_version(@config.source.chart)
      release_values = release.nil? ? nil : @helm.get_release_values(@config.target.name, @config.target.namespace)

      if (release_version == chart.version) && (release_values == @config.target.values)
        @log.info { "No changes." }
        return
      end

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

      @log.info {
        "Release #{@config.target.namespace}/#{@config.target.name} " \
        "is now at revision #{result.revision} " \
        "for #{@config.source.chart}:#{chart.version}."
      }
    rescue ex
      @log.error { ex.message }
    end

    # Retrieve the chart using the configured strategy
    private def get_chart
      entries = @helm.get_chart_entries(
        @config.source.chart,
        @config.source.repository,
        @config.source.repository_username,
        @config.source.repository_password,
      )

      @log.info { "Using '#{@config.source.strategy}' strategy to retrieve chart data." }

      chart = nil
      case @config.source.strategy
      when .latest_created?
        chart = entries
          .sort { |a, b| b.created <=> a.created }
          .first
      when .latest_created_stable?
        chart = entries
          .select { |a| !a.prerelease? }
          .sort! { |a, b| b.created <=> a.created }
          .first
      when .latest_created_prerelease?
        chart = entries
          .select(&.prerelease?)
          .sort! { |a, b| b.created <=> a.created }
          .first
      end

      if chart.nil?
        raise("Chart #{@config.source.chart} not found!")
      end

      chart.as(Watcher::Helm::Client::Chart)
    end
  end
end
