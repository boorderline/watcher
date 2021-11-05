require "log"
require "option_parser"
require "http/server"

require "schedule"

require "./application"

module Watcher
  VERSION = "0.1.0"

  def self.run_workers(config_dir : String)
    if !Dir.exists?(config_dir.as(String))
      raise "Directory #{config_dir} doesn't exist!"
    end

    glob_path = Path.new(config_dir, "*.{yaml,yml}")
    config_files = Dir.glob(glob_path, follow_symlinks: true).map do |f|
      Path[f].expand.to_s
    end
    Log.info { "Loaded #{config_files.size} configurations from #{config_dir}" }

    if config_files.empty?
      raise "Did dot find any configurations. Exiting..."
    end

    results = Channel(Int32).new
    loop do
      config_files.each do |c|
        config = File.open(c) { |f| Watcher::Config::App.from_yaml(f) }
        spawn name: config.name do
          Watcher::Application.new(config).run
          results.send(0)
        end
      end

      config_files.each { results.receive }

      sleep 30.seconds
    end
  end

  def self.run_web
    server = HTTP::Server.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello world!"
    end

    # TODO: Add parameteres fro the web server
    address = server.bind_tcp "0.0.0.0", 8080
    Log.info { "Listening on http://#{address}" }
    server.listen
  end
end

begin
  Log.setup

  # TODO: Support configuration via environment variables (dotenv?)

  config_dir = nil
  OptionParser.parse do |parser|
    parser.banner = "Usage: watcher [args]"

    parser.on("--config-dir=DIR", "-d DIR", "Configurations directory") do |dir|
      config_dir = dir
    end

    parser.on("--help", "-h", "Display this help") do
      puts parser
      exit
    end

    parser.invalid_option do |flag|
      raise "Unkown flag: #{flag}"
    end
  end

  if config_dir.nil?
    raise "Missing configuration directory!"
  end

  spawn Watcher.run_workers(config_dir.as(String))
  Watcher.run_web
rescue ex
  STDERR.puts "ERROR: #{ex.message}"
  exit(1)
end
