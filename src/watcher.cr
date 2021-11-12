require "log"
require "option_parser"

require "./version"
require "./application"

module Watcher
  def self.run(config_dir : String, interval : UInt32)
    if !Dir.exists?(config_dir.as(String))
      raise "Directory #{config_dir} doesn't exist!"
    end

    results = Channel(Int32).new
    loop do
      glob_path = Path.new(config_dir, "*.{yaml,yml}")
      config_files = Dir.glob(glob_path, follow_symlinks: true).map do |f|
        Path[f].expand.to_s
      end

      Log.info { "Found #{config_files.size} configurations ..." }

      # FIXME: Handle possible exceptions in the spawn block
      config_files.each do |c|
        config = File.open(c) { |f| Watcher::Config::App.from_yaml(f) }

        spawn name: config.name do
          Watcher::Application.new(config).run
          results.send(0)
        rescue ex
          Log.error { ex }
        end
      end

      config_files.each { results.receive }
      sleep interval.seconds
    end
  end
end

begin
  Log.setup_from_env

  config_dir = nil
  interval = 10_u32
  OptionParser.parse do |parser|
    parser.banner = "Usage: watcher [args]"

    parser.on("--config-dir=DIR", "-d DIR", "Configurations directory") do |dir|
      config_dir = dir
    end

    parser.on("--interval=SECONDS", "-i SECONDS", "Pooling inteval (default: #{interval})") do |seconds|
      interval = seconds.to_u32
    end

    parser.on("--help", "-h", "Display this help") do
      puts parser
      exit
    end

    parser.on("--version", "-v", "Display version information") do
      puts Watcher::VERSION
      exit
    end

    parser.invalid_option do |flag|
      raise "Unkown flag: #{flag}"
    end
  end

  if config_dir.nil?
    raise "Missing configuration directory!"
  end

  [Signal::INT, Signal::TERM].each do |signal|
    signal.trap do
      puts "Exiting ..."
      exit
    end
  end

  Log.info { "Started Watcher #{Watcher::VERSION}" }
  Log.info { "Loading configurations from: #{config_dir}" }
  Log.info { "Scraping interval: #{interval.seconds} " }

  Watcher.run(config_dir.as(String), interval)
rescue ex
  STDERR.puts "ERROR: #{ex.message}"
  exit 1
end
