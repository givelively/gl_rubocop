---
name: gl-cops
description: >
  Invoke for any task creating a new custom RuboCop cop in this gem: scaffolding a new cop file,
  choosing the right RuboCop node handler method, writing the offense header comment block,
  registering the cop in default.yml, or bumping the gem version. Use whenever the user is writing
  or asking questions about custom cops, whether the query mentions RuboCop explicitly or just
  describes enforcing a code convention with a linter.

---

# Custom RuboCop Cop Instructions

## File Location
- All custom cops go in `lib/gl_rubocop/gl_cops/`.
- File names use `snake_case` matching the class name: `class FooBarBaz` → `foo_bar_baz.rb`.
- Begin every file with `# frozen_string_literal: true`.

## Header Comment Block
Every cop file MUST open with a comment block (before the class definition) that documents the rule with **Good** and **Bad** examples:

```ruby
# frozen_string_literal: true

module GLRubocop
  module GLCops
    # One-sentence description of what the cop enforces.
    #
    # Good:
    #   valid_code_example
    #   another_valid_example
    #
    # Bad:
    #   invalid_code_example
    #   another_invalid_example
    class MyCopName < RuboCop::Cop::Cop
```

## Class Structure
- Extend `RuboCop::Cop::Cop` (or `RuboCop::Cop::Base` for newer-style cops).
- Namespace under `GLRubocop::GLCops`.
- Declare `MSG` as the first constant inside the class:

```ruby
MSG = 'Describe the violation and what to do instead.'
```

For dynamic messages use a format string: `MSG = 'Use %<suggestion>s instead of %<violation>s.'`
then call `format(MSG, suggestion:, violation:)` when adding the offense.

## Registering the Cop

### 1. Add a `require` entry to `default.yml`
Insert the path **alphabetically** in the `require:` list at the top of `default.yml`:

```yaml
require:
  - ./lib/gl_rubocop/gl_cops/my_cop_name.rb
```

### 2. Add an enabled block to `default.yml`
Add a configuration entry **alphabetically** among the `GLCops/` entries:

```yaml
GLCops/MyCopName:
  Enabled: true
```

Include an `Include:` list when the cop only applies to certain file patterns:

```yaml
GLCops/MyCopName:
  Enabled: true
  Include:
    - "**/*_spec.rb"
```

## Version Bump
After adding a new cop, bump the patch version in `lib/gl_rubocop/version.rb`:

```ruby
VERSION = '0.5.5'.freeze  # was 0.5.4
```

Use semantic versioning: patch bump for new cops, minor bump for breaking behavior changes.

## Post-Registration Lint Check
After updating `default.yml`, run RuboCop against the gem itself to confirm the new rule loads cleanly and doesn't trip on existing code:

```
bundle exec rubocop
```

Fix any offenses before considering the cop complete.

## Spec File
Create a matching spec at `spec/gl_rubocop/gl_cops/my_cop_name_spec.rb`. Use `RuboCop::RSpec::ExpectOffense` helpers:

```ruby
# frozen_string_literal: true

RSpec.describe GLRubocop::GLCops::MyCopName do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  it 'registers an offense for bad code' do
    expect_offense(<<~RUBY)
      bad_code_here
      ^^^^^^^^^^^^^ MSG constant text here
    RUBY
  end

  it 'does not register an offense for good code' do
    expect_no_offenses(<<~RUBY)
      good_code_here
    RUBY
  end
end
```
