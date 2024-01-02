module AliyunProxy
  module Pnvs
    class VerifySchemeService < ApiBaseService
      def create(params = { scheme_name: "一键登录认证方案", app_name: "阿里云通信", os_type: "H5", origin: "", url: "" })
        client.request \
          action: "CreateVerifyScheme",
          params: params.stringify_keys.transform_keys(&:camelize),
          opts: {}
      end

      # return:  => { "Message"=>"OK", "RequestId"=>"2CF8BD27-4A06-5C2F-8134-XXXXXXXXXXXX", "Code"=>"OK", "Result"=>true }
      def destroy(scheme_code: "")
        client.request \
          action: "DeleteVerifyScheme",
          params: { SchemeCode: scheme_code },
          opts: {}
      end

      def show(scheme_code: "")
        client.request \
          action: "DescribeVerifyScheme",
          params: { SchemeCode: scheme_code },
          opts: {}
      end
    end
  end
end
