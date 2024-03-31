module AliyunProxy
  module Pnvs
    class AuthTokenService < ApiBaseService
      def generate(url: "", origin: "", scene_code: nil)
        client.request \
          action: "GetAuthToken",
          params: { Url: url, Origin: origin, SceneCode: scene_code.presence || detect_scene_code(url:, origin:) }.compact_blank,
          opts: {}
      end

      private

        def detect_scene_code(url: "", origin: "")
          VerifyScheme.success.find_by \
            scheme_name: URI.parse(url).host,
            app_name: I18n.t("app_name", default: "CODE-LI"),
            os_type: "Web",
            origin:,
            url:
        rescue StandardError => e
          Rails.logger.error "#{self.class.name} detect_scene_code #{e.class.name}: #{e.message}"
          nil
        end
    end
  end
end
