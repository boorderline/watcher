require "yaml"
require "uri"
require "http/client"
require "semantic_version"

module Watcher::Helm
  class Client
    Log = ::Log.for(self)

    # Retrieves all version entries for a given chart in a repository.
    def get_chart_entries(chart : String, repo : String, username : String? = nil, password : String? = nil)
      url = URI.parse(repo)
      url.user = username
      url.password = password
      url.path = Path.posix(url.path, "index.yaml").to_s

      HTTP::Client.get(url.to_s) do |response|
        unless response.success?
          raise("Cannot retrieve #{url}: #{response.status_code}")
        end

        index = Index.from_yaml(response.body_io.gets_to_end)
        unless index.entries.has_key?(chart)
          raise("Cannot find '#{chart}' chart in the repository.")
        end

        index.entries[chart]
      end
    end

    # Installs/upgrades a release to a new version of a chart.
    def deploy(release : String, chart : String, version : String,
               repo : String, username : String? = nil, password : String? = nil,
               namespace = "default", create_namespace = false,
               values : String? = nil, reset_values = false)
      opts = {
        "version"   => version,
        "repo"      => repo,
        "namespace" => namespace,
        "install"   => nil,
        "output"    => "yaml",
      }

      opts["username"] = username unless username.nil?
      opts["password"] = password unless password.nil?
      opts["create-namespace"] = nil if create_namespace
      opts["reset-values"] = nil if reset_values

      unless values.nil?
        values_file = File.tempfile
        File.write(values_file.path, values.as(String))
        opts["values"] = values_file.path
      end

      output = execute_command(["upgrade", release, chart], opts)
      Deploy.from_yaml(output)
    end

    # Lists all of the releases for a specified namespace.
    # TODO: Fix the 256 limit for the listing.
    def list_releases(namespace = "default")
      output = execute_command(["list"], {
        "namespace" => namespace,
        "output"    => "yaml",
      })
      Array(Release).from_yaml(output)
    end

    # Retrieves historical revisions for a given release.
    def release_history(release_name : String, namespace = "default")
      output = execute_command(["history", release_name], {
        "namespace" => namespace,
        "output"    => "yaml",
      })
      Array(Client::Revision).from_yaml(output)
    end

    # Retrieves values file for a given release.
    def get_release_values(release : String, namespace = "default")
      output = execute_command(["get", "values", release], {
        "namespace" => namespace,
        "output"    => "yaml",
      })
      YAML.parse(output)
    end

    private def execute_command(params : Array(String), opts = Hash(String, String?).new)
      args = params.concat(opts.flat_map { |k, v| v.nil? ? ["--#{k}"] : ["--#{k}", v] })

      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run("helm", args: args, output: stdout, error: stderr, shell: true)
      Log.debug { args.join(" ") }

      unless status.success?
        raise stderr.to_s.chomp
      end

      stdout.to_s
    end

    struct Release
      include YAML::Serializable

      @[YAML::Field(key: "name")]
      # Release name
      getter name : String

      @[YAML::Field(key: "namespace")]
      # Release namespace scope
      getter namespace : String

      @[YAML::Field(key: "revision")]
      # Release revision
      getter revision : String

      @[YAML::Field(key: "updated")]
      # Last updated
      getter updated : String

      @[YAML::Field(key: "status")]
      # Status of the release
      getter status : String

      @[YAML::Field(key: "chart")]
      # Chart name (including version)
      getter chart : String

      @[YAML::Field(key: "app_version")]
      # Release application version
      getter app_version : String

      def extract_chart_version(name)
        @chart.gsub(/^#{name}-/, "")
      end
    end

    struct Revision
      include YAML::Serializable

      @[YAML::Field(key: "revision")]
      # Revision number
      getter revision : UInt32

      @[YAML::Field(key: "updated")]
      # Revision update date
      getter updated : String

      @[YAML::Field(key: "status")]
      # Revision status
      getter status : String

      @[YAML::Field(key: "chart")]
      # Revision chart name
      getter chart : String

      @[YAML::Field(key: "app_version")]
      getter app_version : String

      @[YAML::Field(key: "description")]
      getter description : String
    end

    struct Deploy
      include YAML::Serializable

      @[YAML::Field(key: "name")]
      getter name : String

      @[YAML::Field(key: "info")]
      getter info : Info

      @[YAML::Field(key: "version")]
      getter revision : UInt32

      @[YAML::Field(key: "namespace")]
      getter namespace : String

      struct Info
        include YAML::Serializable

        @[YAML::Field(key: "first_deployed")]
        getter first_deployed : String

        @[YAML::Field(key: "last_deployed")]
        getter last_deployed : String

        @[YAML::Field(key: "deleted")]
        getter deleted : String

        @[YAML::Field(key: "description")]
        getter description : String

        @[YAML::Field(key: "status")]
        getter status : String

        @[YAML::Field(key: "notes")]
        getter notes : String
      end
    end

    struct Chart
      include YAML::Serializable

      @[YAML::Field(key: "apiVersion")]
      getter api_version : String

      @[YAML::Field(key: "name")]
      # Chart name
      getter name : String

      @[YAML::Field(key: "version")]
      # Chart version
      getter version : String

      @[YAML::Field(key: "appVersion")]
      # Application version
      getter app_version : String?

      @[YAML::Field(key: "description")]
      getter description : String?

      @[YAML::Field(key: "type")]
      # Type of chart
      getter type : String?

      @[YAML::Field(key: "deprecated")]
      getter deprecated : Bool?

      @[YAML::Field(key: "created")]
      # Date when chart was uploaded in the repository
      getter created : String

      # Check if the current version is a pre-release
      def prerelease?
        !SemanticVersion.parse(@version).prerelease.identifiers.empty?
      end
    end

    struct Index
      include YAML::Serializable

      @[YAML::Field(key: "apiVersion")]
      # Index API version
      getter api_version : String

      @[YAML::Field(key: "entries")]
      # List of entries in the repository
      getter entries : Hash(String, Array(Chart))
    end
  end
end
