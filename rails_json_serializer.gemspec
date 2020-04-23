Gem::Specification.new do |s|
  s.name = %q{rails_json_serializer}
  s.version = "1.0.1"
  s.date = %q{2020-04-22}
  s.authors = ["benjamin.dana.software.dev@gmail.com"]
  s.summary = %q{An ActiveRecord JSON Serializer with deeply nested includes.}
  s.files = [
    "lib/serializer.rb",
    "lib/serializer/concern.rb",
    "lib/serializer/configuration.rb",
  ]
  s.require_paths = ["lib"]
  s.homepage = 'https://github.com/danabr75/rails_json_serializer'
  s.add_runtime_dependency 'rails', '>= 5.0'
  s.required_ruby_version = '>= 2.4'
end