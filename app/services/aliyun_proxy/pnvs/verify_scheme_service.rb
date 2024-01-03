module AliyunProxy
  module Pnvs
    class VerifySchemeService < ApiBaseService
      # return => { "RequestId"=>"2E9709D2-3A6D-5FE8-B45B-XXXXXXXXXXXX", "GateVerifySchemeDTO"=>{"SchemeCode"=>"FC220000000000000"}, "HttpStatusCode"=>200, "Code"=>"OK", "Success"=>true }
      def add(params = { scheme_name: "一键登录认证方案", app_name: "阿里云通信", os_type: "Web", origin: "", url: "" })
        client.request(
          action: "CreateVerifyScheme",
          params: params.stringify_keys.transform_keys(&:camelize),
          opts: {}
        ).then { create_verify_scheme(params, _1) }
      end

      # return => { "Message"=>"OK", "RequestId"=>"2CF8BD27-4A06-5C2F-8134-XXXXXXXXXXXX", "Code"=>"OK", "Result"=>true }
      def delete(scheme_code: "")
        client.request(
          action: "DeleteVerifyScheme",
          params: { SchemeCode: scheme_code },
          opts: {}
        ).then { destroy_verify_scheme(scheme_code, _1) }
      end

      # return => { "Message"=>"OK", "RequestId"=>"EBD9D720-B3FF-5CF6-B1B3-96287C21A453", "Code"=>"OK" }
      def query(scheme_code: "")
        client.request(
          action: "DescribeVerifyScheme",
          params: { SchemeCode: scheme_code },
          opts: {}
        ).then { show_verify_scheme(scheme_code, _1) }
      end

      private

        def create_verify_scheme(params, info)
          return if info["Code"] != "OK"

          VerifyScheme.create params.merge(scheme_code: info.dig("GateVerifySchemeDTO", "SchemeCode"), state: :success)
        end

        def destroy_verify_scheme(scheme_code, info)
          return if info["Code"] != "OK"

          VerifyScheme.find_by(scheme_code:)&.destroy
        end

        def show_verify_scheme(scheme_code, info)
          return if info["Code"] != "OK"

          VerifyScheme.find_by(scheme_code:)
        end
    end
  end
end
