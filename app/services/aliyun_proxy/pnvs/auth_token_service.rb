module AliyunProxy
  module Pnvs
    class AuthTokenService < ApiBaseService
      def generate(url: "", origin: "")
        client.request \
          action: "GetAuthToken",
          params: { Url: url, Origin: origin },
          opts: {}
      end
    end
  end
end
