# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "qumulo/rest/gem_version"

QUMULO_PRODUCT_NAME = "Qumulo Core appliance"
Gem::Specification.new do |spec|
  spec.name          = "qumulo-rest"
  spec.version       = Qumulo::Rest::GEM_VERSION
  spec.authors       = ["Qumulo"]
  spec.email         = ["support@qumulo.com"]
  spec.description   = %q{Client library for #{QUMULO_PRODUCT_NAME}}
  spec.summary       = %q{Provides classes for accessing RESTful API defined for #{QUMULO_PRODUCT_NAME}}
  spec.homepage      = "http://www.qumulo.com"
  spec.license       = "Apache"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "json"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-ci"

  def ver_to_i(version_string)
    a = version_string.split(".")
    10000 * a[0].to_i + 100 * a[1].to_i + 1 * a[2].to_i
  end

  if ver_to_i(RUBY_VERSION) >= ver_to_i("1.9.2")
    spec.add_development_dependency "minitest-reporters"
    spec.add_development_dependency "simplecov"
    spec.add_development_dependency "simplecov-rcov"
  end

end
