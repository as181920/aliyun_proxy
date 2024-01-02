require "jbuilder"
require "faraday"
require "addressable/uri"
require "aliyunsdkcore"

module AliyunProxy
  class Engine < ::Rails::Engine
    isolate_namespace AliyunProxy

    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    config.to_prepare do
      Dir.glob(AliyunProxy::Engine.root.join("app/extensions/**/*_extension*.rb")).each do |c|
        require_dependency c
      end
    end

    initializer "chuanglan_proxy.assets.precompile" do |app|
      app.config.assets.precompile += %w[
        aliyun_proxy_manifest.js
      ]
    end

    config.generators do |g|
      g.orm             :active_record
      g.template_engine :erb
      g.stylesheets     false
      g.javascripts     false
      g.helper          false
      g.test_framework  nil
      g.skip_routes     true
    end
  end
end
