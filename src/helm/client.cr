require "json"

module Watcher::Helm
  class Client
    getter namespace : String

    def initialize(@namespace = "default")
    end

    def deploy(name : String, chart : String, repository : String, version : String)
      output = execute_command(["upgrade", name, chart], {
        "repo"    => repository,
        "version" => version,
        "install" => nil,
      })
      Client::Deploy.from_json(output)
    end

    def list_releases
      output = execute_command(["list"])

      # TODO: Fix the 256 limit for the listing.

      Array(Client::Release).from_json(output)
    end

    def release_history(release_name : String)
      output = execute_command(["history", release_name])
      Array(Client::Revision).from_json(output)
    end

    private def execute_command(args : Array(String), options = Hash(String, String).new)
      helm_args = args.concat(
        options.merge({
          "namespace" => @namespace,
          "output"    => "json",
        }).flat_map { |k, v| v.nil? ? ["--#{k}"] : ["--#{k}", v] }
      )

      stdout_io = IO::Memory.new
      stderr_io = IO::Memory.new
      status = Process.run("helm",
        args: helm_args,
        output: stdout_io,
        error: stderr_io,
        shell: true,
      )

      raise stderr_io.to_s unless status.success?

      stdout_io.to_s
    end
  end

  struct Client::Repo
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    getter name : String

    @[JSON::Field(key: "url")]
    getter url : String
  end

  struct Client::Release
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    getter name : String

    @[JSON::Field(key: "namespace")]
    getter namespace : String

    @[JSON::Field(key: "revision")]
    getter revision : String

    @[JSON::Field(key: "updated")]
    getter updated : String

    @[JSON::Field(key: "status")]
    getter status : String

    @[JSON::Field(key: "chart")]
    getter chart : String

    @[JSON::Field(key: "app_version")]
    getter app_version : String

    def extract_chart_version(name)
      @chart.gsub(/^#{name}-/, "")
    end
  end

  struct Client::Revision
    include JSON::Serializable

    @[JSON::Field(name: "revision")]
    getter revision : UInt32

    @[JSON::Field(name: "updated")]
    getter updated : String

    @[JSON::Field(name: "status")]
    getter status : String

    @[JSON::Field(name: "chart")]
    getter chart : String

    @[JSON::Field(name: "app_version")]
    getter app_version : String

    @[JSON::Field(name: "description")]
    getter description : String
  end

  struct Client::Deploy
    include JSON::Serializable

    @[JSON::Field(name: "name")]
    getter name : String

    @[JSON::Field(name: "info")]
    getter info : Client::Deploy::Info

    @[JSON::Field(name: "version")]
    getter version : UInt32

    @[JSON::Field(name: "namespace")]
    getter namespace : String
  end

  struct Client::Deploy::Info
    include JSON::Serializable

    @[JSON::Field(name: "first_deployed")]
    getter first_deployed : String

    @[JSON::Field(name: "last_deployed")]
    getter last_deployed : String

    @[JSON::Field(name: "deleted")]
    getter deleted : String

    @[JSON::Field(name: "description")]
    getter description : String

    @[JSON::Field(name: "status")]
    getter status : String

    @[JSON::Field(name: "notes")]
    getter notes : String
  end
end
