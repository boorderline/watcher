require "log"
require "option_parser"
require "http/server"

require "./application"

module Watcher
  VERSION = "0.1.0"

  def self.run_workers(config_dir : String?)
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

    apps.each { |c| spawn Watcher::Application.new(c).run }
  end

  def self.run_web
    server = HTTP::Server.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello world!"
    end

    address = server.bind_tcp "0.0.0.0", 8080
    Log.info { "Listening on http://#{address}" }
    server.listen
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

  Watcher.run_workers(config_dir)
  Watcher.run_web
rescue ex
  STDERR.puts "ERROR: #{ex.message}"
  exit(1)
end
