require "./spec_helper"

describe Watcher::Helm do
  it "should deserialize object" do
    content = File.read(Path.new(Dir.current, "manifests/example1.yaml"))
    manifest = Watcher::Helm::Manifest.from_yaml(content)

    manifest.entries.size.should eq(27)
  end
end
