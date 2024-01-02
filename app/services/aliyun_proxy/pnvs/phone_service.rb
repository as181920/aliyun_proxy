module AliyunProxy
  module Pnvs
    class PhoneService < ApiBaseService
      # return {"RequestId"=>"921E9AD9-0E7E-5EE8-A515-XXXXXXXXXXXX", "Data"=>{"Mobile"=>"13800000000"}, "Code"=>"OK"}
      def get_number(sp_token: "")
        client.request \
          action: "GetPhoneWithToken",
          params: { SpToken: sp_token },
          opts: {}
      end
    end
  end
end
