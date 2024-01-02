module AliyunProxy
  module Pnvs
    class ApiBaseService
      attr_reader :access_key_id, :access_key_secret

      def initialize(access_key_id, access_key_secret)
        @access_key_id = access_key_id
        @access_key_secret = access_key_secret
      end

      private

        def client
          @client ||= ::AliyunSDKCore::RPCClient.new \
            endpoint: END_POINT,
            api_version: API_VERSION,
            access_key_id:,
            access_key_secret:
        end
    end
  end
end
