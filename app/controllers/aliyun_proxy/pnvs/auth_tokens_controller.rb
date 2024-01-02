module AliyunProxy
  class Pnvs::AuthTokensController < Pnvs::BaseController
    def create
      @auth_token = Pnvs::AuthTokenService.new(
        (ENV.fetch("aliyun_pnvs_access_key_id", nil) || ENV.fetch("aliyun_access_key_id", nil)),
        (ENV.fetch("aliyun_pnvs_access_key_secret", nil) || ENV.fetch("aliyun_access_key_secret", nil))
      ).generate(**auth_token_params.to_h.symbolize_keys)

      render json: @auth_token
    end

    private

      def auth_token_params
        params.fetch(:auth_token, {}).permit :url, :origin
      end
  end
end
