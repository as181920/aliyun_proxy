module AliyunProxy
  module Pnvs
    class AuthTokenService < ApiBaseService
      def generate(url: "", origin: "", scene_code: nil)
        client.request \
          action: "GetAuthToken",
          params: { Url: url, Origin: origin, SceneCode: scene_code }.compact_blank,
          opts: {}
      end
    end
  end
end
