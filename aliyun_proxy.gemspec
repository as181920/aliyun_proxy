require_relative "lib/aliyun_proxy/version"

Gem::Specification.new do |spec|
  spec.name        = "aliyun_proxy"
  spec.version     = AliyunProxy::VERSION
  spec.authors     = ["Andersen Fan"]
  spec.email       = ["as181920@gmail.com"]
  spec.homepage    = "https://github.com/as181920/aliyun_proxy"
  spec.summary     = "Alibaba Cloud api proxy"
  spec.description = "阿里云服务对接"
  spec.license     = "MIT"

  spec.metadata["allowed_push_host"] = "https://gems.dd-life.com"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "jbuilder"
  spec.add_dependency "faraday"
  spec.add_dependency "addressable"
end
