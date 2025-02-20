# gl_rubocop

A shareable configuration of rules we use at Give Lively to lint our Ruby code.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gl_rubocop', require: false
```

And then execute:

```bash
 bundle install
```

Or install it yourself as:

```bash
 gem install gl_lint
```

And finally add this to the top of your project's RuboCop configuration file:

```yml
 inherit_gem:
    gl_rubocop: default.yml
```

Any `Include` or `Exclude` configuration provided will be merged with RuboCop's defaults.

For more information about inheriting configuration from a gem please check
[RuboCop's
documentation](https://docs.rubocop.org/rubocop/configuration.html#inheriting-configuration-from-a-dependency-gem).

## Making changes and publishing

1. As per our code agreements, all code changes to this gem are required to be made via pull request with final approval from at least one Give Lively engineer.

2. When creating a pull request, ensure that your code changes include an update to the gem's [version number](https://github.com/givelively/gl_rubocop/blob/main/lib/gl_rubocop/version.rb) using [semantic versioning](https://semver.org/)

3. After getting approval, merge your changes to `main`.

4. Once your CI build finishes sucessfully, pull the latest version of `main` locally.

5. Run the command `gem build`. This bundles the relevant files from the gem and prepares it to be published to [rubygems.org](https://rubygems.org/). (Note: if you are not one of the owners listed you may need to request that that this and the following step be completed by one of the gem owners listed in CODEOWNERS)

6. Once the bundle is successfully created there should be a new file created locally that looks like `gl_rubocop-<new_gem_version_number>.gem`.

7. Run the command `gem push gl_rubocop-<new_gem_version_number>.gem`.

8. Following the authorization prompts listed by the gem command.

9. Your changes have now been published to the rubygems registry.

## Testing Locally
It's likely the case you'll want to test your changes locally before opening a PR, getting approval, and publishing the gem.

To do so, complete the following steps:

1. Save the changes to whichever files you have modified.

2. Run the command `gem build` to create the bundle (this may require you to have bumped the version number)

3. Go to the Gemfile in whichever ruby-based repo you want to test your rubocop changes against

4. Create an entry for gl_rubocop specifiying the *relative* path to your local `gl_rubocop` repo (ex. `../code/gl_rubocop`):

```ruby
gem 'gl_rubocop', '~> 0.2.9', path: '../path/to/your/local/gl_rubocop'
```

5. Within the same repo as the Gemfile you just updated run `bundle install`

6. Finally add the following lines to your rubocop configuration file

```yml
 inherit_gem:
    gl_rubocop: default.yml
```

7. Now you can test your rubocop changes local with the target repo.