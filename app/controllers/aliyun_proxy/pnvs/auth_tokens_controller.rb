module AliyunProxy
  class Pnvs::AuthTokensController < Pnvs::BaseController
    def create
      @auth_token = Pnvs::AuthTokenService.new(
        (ENV.fetch("aliyun_pnvs_access_key_id", nil) || ENV.fetch("aliyun_access_key_id", nil)),
        (ENV.fetch("aliyun_pnvs_access_key_secret", nil) || ENV.fetch("aliyun_access_key_secret", nil))
      ).generate(**auth_token_params.to_h.symbolize_keys)

      render :create, formats: :json
    rescue StandardError => e
      logger.error "#{self.class.name} #{action_name} #{e.class.name}: #{e.message}"
      @error_message = I18n.t("aliyun_proxy.flash.get_pnvs_auth_token_failed")
      render "aliyun_proxy/shared/error", formats: :json, status: :bad_request
    end

    private

      def auth_token_params
        # The query's auth_token authenticates the caller; PNVS inputs belong to the body.
        ActionController::Parameters.new(request.request_parameters).fetch(:auth_token, {}).permit :url, :origin
      end
  end
end
