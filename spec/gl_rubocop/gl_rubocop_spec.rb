# frozen_string_literal: true

RSpec.describe GLRubocop do
  it 'has a version number' do
    expect(GLRubocop::VERSION).not_to be_nil
  end

  # TODO: Add specs to ensure proper configuration is used

  describe "default.yml file" do
    it "keys are ordered alphabetically" do
      default_rules = YAML.safe_load(File.read("default.yml"))
      checked_rule_keys = default_rules.keys - %w[require]

      expect(checked_rule_keys).to eq checked_rule_keys.sort
    end
  end
end
