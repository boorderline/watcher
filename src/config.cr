require "yaml"

module Watcher::Config
  struct App
    include YAML::Serializable

    @[YAML::Field(key: "version")]
    getter version : String

    @[YAML::Field(key: "name")]
    getter name : String

    @[YAML::Field(key: "source")]
    getter source : Source

    @[YAML::Field(key: "target")]
    getter target : Target

    struct Source
      include YAML::Serializable

      @[YAML::Field(key: "repository")]
      getter repository : String

      @[YAML::Field(key: "repository_username")]
      getter repository_username : String?

      @[YAML::Field(key: "repository_password")]
      getter repository_password : String?

      @[YAML::Field(key: "chart")]
      getter chart : String

      @[YAML::Field(key: "version")]
      getter version : String?

      @[YAML::Field(key: "allow_prereleases")]
      getter allow_prereleases : Bool = false
    end

    struct Target
      include YAML::Serializable

      @[YAML::Field(key: "name")]
      getter name : String

      @[YAML::Field(key: "namespace")]
      getter namespace : String

      @[YAML::Field(key: "create_namespace")]
      getter create_namespace : Bool = false

      @[YAML::Field(key: "values")]
      getter values : YAML::Any?
    end
  end
end
