module AliyunProxy
  class ApiDocsController < ApplicationController
    SPECIFICATIONS = { "user" => "user.json", "callbacks" => "callbacks.json" }.freeze

    def show
      filename = SPECIFICATIONS[params[:role]]
      return head :not_found unless filename

      send_file AliyunProxy::Engine.root.join("config/openapi", filename), type: "application/json; charset=utf-8", disposition: "inline"
    end
  end
end
