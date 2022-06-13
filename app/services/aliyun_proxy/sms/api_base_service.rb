module AliyunProxy
  module Sms
    class ApiBaseService
      attr_reader :access_key_id, :access_key_secret

      def initialize(access_key_id, access_key_secret)
        @access_key_id = access_key_id
        @access_key_secret = access_key_secret
      end

      def api_client
        @api_client ||= ::AliyunSms::ApiClient.new(access_key_id, access_key_secret)
      end
    end
  end
end
