require "yaml"

require "../converters"

module Watcher::Helm
  struct Manifest
    include YAML::Serializable

    @[YAML::Field(key: "apiVersion")]
    getter api_version : String

    @[YAML::Field(key: "entries")]
    getter entries : Hash(String, Array(ManifestEntry))

    @[YAML::Field(key: "generated", converter: Time::ISO8601Converter)]
    getter generated : Time
  end

  struct ManifestEntry
    include YAML::Serializable

    @[YAML::Field(key: "apiVersion")]
    getter api_version : String

    @[YAML::Field(key: "appVersion")]
    getter app_version : String?

    @[YAML::Field(key: "created", converter: Time::ISO8601Converter)]
    getter created : Time

    @[YAML::Field(key: "description")]
    getter description : String

    @[YAML::Field(key: "digest")]
    getter digest : String

    @[YAML::Field(key: "icon")]
    getter icon : String?

    @[YAML::Field(key: "maintainers")]
    getter maintainers : Array(Maintainer)?

    @[YAML::Field(key: "name")]
    getter name : String

    @[YAML::Field(key: "sources")]
    getter sources : Array(String)?

    @[YAML::Field(key: "type")]
    getter type : String?

    @[YAML::Field(key: "urls")]
    getter urls : Array(String)

    @[YAML::Field(key: "version")]
    getter version : String
  end

  struct Maintainer
    include YAML::Serializable

    @[YAML::Field(key: "email")]
    getter email : String?

    @[YAML::Field(key: "name")]
    getter name : String?
  end
end
