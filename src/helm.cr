require "json"
require "yaml"

module Watcher::Helm
  class Client
    def initialize
    end

    def get_latest_chart(chart : String,
                         repo : String, username : String? = nil, password : String? = nil)
      opts = {"repo" => repo}

      opts["username"] = username unless username.nil?
      opts["password"] = password unless password.nil?

      output = execute_command(["show", "chart", chart], opts)
      Client::Chart.from_yaml(output)
    end

    def deploy(release : String, chart : String, version : String,
               repo : String, username : String? = nil, password : String? = nil,
               namespace = "default", create_namespace = false,
               values : String? = nil)
      opts = {
        "version"   => version,
        "repo"      => repo,
        "namespace" => namespace,
        "install"   => nil,
        "output"    => "json",
      }

      opts["username"] = username unless username.nil?
      opts["password"] = password unless password.nil?
      opts["create-namespace"] = nil if create_namespace

      unless values.nil?
        values_file = File.tempfile
        File.write(values_file.path, values.as(String))
        opts["values"] = values_file.path
      end

      output = execute_command(["upgrade", release, chart], opts)
      Client::Deploy.from_json(output)
    end

    # TODO: Fix the 256 limit for the listing.
    def list_releases(namespace = "default")
      opts = {
        "namespace" => namespace,
        "output"    => "json",
      }

      output = execute_command(["list"], opts)
      Array(Client::Release).from_json(output)
    end

    def release_history(release_name : String, namespace = "default")
      opts = {
        "namespace" => namespace,
        "output"    => "json",
      }

      output = execute_command(["history", release_name], opts)
      Array(Client::Revision).from_json(output)
    end

    def get_revision_values(release : String, revision = nil, namespace = "default", all = false)
      opts = Hash(String, String?){
        "namespace" => namespace,
        "output"    => "yaml",
      }

      opts["all"] = nil if all
      opts["revision"] = revision unless revision.nil?

      output = execute_command(["get", "values", release], opts)
      YAML.parse(output)
    end

    private def execute_command(params : Array(String), opts = Hash(String, String?).new)
      args = params.concat(
        opts.flat_map { |k, v| v.nil? ? ["--#{k}"] : ["--#{k}", v] }
      )

      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run("helm", args: args, output: stdout, error: stderr, shell: true)

      unless status.success?
        raise stderr.to_s.chomp
      end

      stdout.to_s
    end
  end

  struct Client::Release
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    getter name : String

    @[JSON::Field(key: "namespace")]
    getter namespace : String

    @[JSON::Field(key: "revision")]
    getter revision : String

    # TODO : Convert this to Time object
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

    @[JSON::Field(key: "revision")]
    getter revision : UInt32

    # TODO : Convert this to Time object
    @[JSON::Field(key: "updated")]
    getter updated : String

    @[JSON::Field(key: "status")]
    getter status : String

    @[JSON::Field(key: "chart")]
    getter chart : String

    @[JSON::Field(key: "app_version")]
    getter app_version : String

    @[JSON::Field(key: "description")]
    getter description : String
  end

  struct Client::Deploy
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    getter name : String

    @[JSON::Field(key: "info")]
    getter info : Info

    @[JSON::Field(key: "version")]
    getter version : UInt32

    @[JSON::Field(key: "namespace")]
    getter namespace : String

    struct Info
      include JSON::Serializable

      # TODO : Convert this to Time object
      @[JSON::Field(key: "first_deployed")]
      getter first_deployed : String

      # TODO : Convert this to Time object
      @[JSON::Field(key: "last_deployed")]
      getter last_deployed : String

      @[JSON::Field(key: "deleted")]
      getter deleted : String

      @[JSON::Field(key: "description")]
      getter description : String

      @[JSON::Field(key: "status")]
      getter status : String

      @[JSON::Field(key: "notes")]
      getter notes : String
    end
  end

  struct Client::Chart
    include YAML::Serializable

    @[YAML::Field(key: "apiVersion")]
    getter api_version : String

    @[YAML::Field(key: "name")]
    getter name : String

    @[YAML::Field(key: "version")]
    getter version : String

    @[YAML::Field(key: "kubeVersion")]
    getter kube_version : String?

    @[YAML::Field(key: "description")]
    getter description : String?

    @[YAML::Field(key: "type")]
    getter type : String?

    @[YAML::Field(key: "keywords")]
    getter keywords : Array(String)?

    @[YAML::Field(key: "home")]
    getter home : String?

    @[YAML::Field(key: "sources")]
    getter sources : Array(String)?

    @[YAML::Field(key: "dependencies")]
    getter dependencies : Array(Dependency)?

    @[YAML::Field(key: "maintainers")]
    getter maintainer : Array(Maintainer)?

    @[YAML::Field(key: "icon")]
    getter icon : String?

    @[YAML::Field(key: "appVersion")]
    getter app_version : String?

    @[YAML::Field(key: "deprecated")]
    getter deprecated : Bool?

    @[YAML::Field(key: "annotations")]
    getter annotations : Hash(String, String)?

    struct Maintainer
      include YAML::Serializable

      @[YAML::Field(key: "name")]
      getter name : String

      @[YAML::Field(key: "email")]
      getter email : String?

      @[YAML::Field(key: "url")]
      getter url : String?
    end

    struct Dependency
      include YAML::Serializable

      @[YAML::Field(key: "name")]
      getter name : String

      @[YAML::Field(key: "version")]
      getter version : String

      @[YAML::Field(key: "repository")]
      getter repository : String?

      @[YAML::Field(key: "condition")]
      getter condition : String?

      @[YAML::Field(key: "tags")]
      getter tags : Array(String)?

      #     import-values: # (optional)
      #       - ImportValues holds the mapping of source values to parent key to be imported. Each item can be a string or pair of child/parent sublist items.
      #     alias: (optional) Alias to be used for the chart. Useful when you have to add the same chart multiple times
    end
  end
end
