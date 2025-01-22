# gl_rubocop
A shareable configuration of rules we use at Give Lively to lint our Ruby code.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'gl_rubocop', require: false
```

And then execute:
```
$ bundle install
```

Or install it yourself as:
```
$ gem install gl_lint
```

And finally add this to the top of your project's RuboCop configuration file:

```yml
 inherit_gem:
    rubocop-shopify: rubocop.yml
```
Any `Include` or `Exclude` configuration provided will be merged with RuboCop's defaults.

For more information about inheriting configuration from a gem please check
[RuboCop's
documentation](https://docs.rubocop.org/rubocop/configuration.html#inheriting-configuration-from-a-dependency-gem).

## Making changes and Publishing

1. As per our code agreements, all code changes to this gem are required to be made via pull request with final approval from at least one Give Lively engineer.

2. When creating a pull request, ensure that your code changes include an update to the gem's [version number](https://github.com/givelively/gl_rubocop/blob/main/lib/gl_rubocop/version.rb) using [semantic versioning](https://semver.org/)

3. After getting approval, merge your changes to `main`.

4. Once your CI build finishes sucessfully, pull the latest version of `main` locally.

5. Run the command `gem build`. This bundles the relevant files from the gem and prepares it to be published to [rubygems.org](https://rubygems.org/). (Note: if you are not one of the owners listed you may need to request that that this and the following step be completed by one of the gem owners listed in CODEOWNERS)

6. Once the bundle is successfully created there should be a new file created locally that looks like `gl_rubocop-<new_gem_version_number>.gem`.

7. Run the command `gem push gl_rubocop-<new_gem_version_number>.gem`.

8. Following the authorization prompts listed by the gem command.

9. Your changes have now been published to the rubygems registry