module AliyunProxy
  class Captcha::ApiDocsController < Captcha::BaseController
    def show
      send_file AliyunProxy::Engine.root.join("config/openapi/openapi.json"), type: "application/json; charset=utf-8", disposition: "inline"
    end
  end
end
