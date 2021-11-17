require "yaml"

module Watcher
  struct Config
    include YAML::Serializable

    @[YAML::Field(key: "version")]
    # Configuration version
    getter version : String

    @[YAML::Field(key: "name")]
    # Application name
    getter name : String

    @[YAML::Field(key: "source")]
    # Source definition
    getter source : Source

    @[YAML::Field(key: "target")]
    # Target definition
    getter target : Target

    struct Source
      include YAML::Serializable

      enum FetchStrategy
        LatestCreated
        LatestCreatedStable
        LatestCreatedPrerelease
      end

      @[YAML::Field(key: "repository")]
      # Chart repository url
      getter repository : String

      @[YAML::Field(key: "repository_username")]
      # Chart repository username
      getter repository_username : String?

      @[YAML::Field(key: "repository_password")]
      # Chart repository password
      getter repository_password : String?

      @[YAML::Field(key: "chart")]
      # Chart name
      getter chart : String

      @[YAML::Field(key: "strategy")]
      getter strategy = FetchStrategy::LatestCreated
    end

    struct Target
      include YAML::Serializable

      @[YAML::Field(key: "name")]
      # Release name
      getter name : String

      @[YAML::Field(key: "namespace")]
      # Namespace scope
      getter namespace : String

      @[YAML::Field(key: "create_namespace")]
      # Create the release namespace if not present
      getter create_namespace : Bool = false

      @[YAML::Field(key: "values")]
      # Specify values in a YAML
      getter values : YAML::Any?
    end
  end
end
