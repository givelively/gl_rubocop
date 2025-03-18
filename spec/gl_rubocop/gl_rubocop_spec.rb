# frozen_string_literal: true

RSpec.describe GLRubocop do
  it 'has a version number' do
    expect(GLRubocop::VERSION).not_to be_nil
  end

  # TODO: Add specs to ensure proper configuration is used

  describe 'default.yml file' do
    it 'keys are ordered alphabetically' do
      default_rules = YAML.safe_load_file('default.yml')
      target_rule_keys = (default_rules.keys - %w[require]).sort

      # The rules should be ordered alphabetically, except for require (which comes first)
      expect(default_rules.keys).to eq(%w[require] + target_rule_keys)
    end
  end
end
