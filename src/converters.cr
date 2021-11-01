module Time::ISO8601Converter
  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time
    unless node.is_a?(YAML::Nodes::Scalar)
      node.raise "Expected scalar, not #{node.class}"
    end

    Time.parse_iso8601(node.value)
  end
end
