require "yaml"

module Watcher::Config
  struct App
    include YAML::Serializable

    @[YAML::Field(key: "version")]
    getter version : String

    @[YAML::Field(key: "name")]
    getter name : String

    @[YAML::Field(key: "scrape_config")]
    getter scrape : Scrape

    @[YAML::Field(key: "source")]
    getter source : Source

    @[YAML::Field(key: "target")]
    getter target : Target
  end

  struct Source
    include YAML::Serializable

    @[YAML::Field(key: "repository")]
    getter repository : String

    @[YAML::Field(key: "chart")]
    getter chart : String
  end

  struct Target
    include YAML::Serializable

    @[YAML::Field(key: "name")]
    getter name : String

    @[YAML::Field(key: "namespace")]
    getter namespace : String

    # TODO: Add support for values.yaml
  end

  struct Scrape
    include YAML::Serializable

    @[YAML::Field(key: "interval")]
    getter interval : UInt32 = 30

    @[YAML::Field(key: "headers")]
    getter headers : Hash(String, String)?
  end

  def self.load_from_dir(dir : String) : Array(App)
    Dir.glob("#{dir}/*.{yaml,yml}").map do |file|
      File.open(Path[file].expand) { |f| App.from_yaml(f) }
    end
  end
end
