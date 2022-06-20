module AliyunProxy
  module Sms
    class SignService < ApiBaseService
      STATE_MAP = {
        AUDIT_STATE_INIT: :approving,
        AUDIT_STATE_PASS: :approved,
        AUDIT_STATE_NOT_PASS: :rejected,
        AUDIT_STATE_CANCEL: :cancelled,
        0 => :approving,
        1 => :approved,
        2 => :rejected
      }.with_indifferent_access.freeze

      def add
      end

      def modify
      end

      def delete
      end

      def query(name)
        api_client.query_sign(name)
      end

      def sync_sign(name)
        query(name).then { |sign_info| save_sign(sign_info) }
      end

      def list(page: 1, per: 10)
        api_client.query_sign_list(page:, per:)
      end

      def sync_list
        sign_infos = []

        (1..).each do |page|
          page_infos = Array(list(page:)["SmsSignList"])
          page_infos.present? ? sign_infos.concat(page_infos) : break
        end

        sign_infos
          .sort_by { |sign_info| sign_info["CreateDate"] }
          .map { |sign_info| save_sign(sign_info) }
          .tap { |signs| Sign.where.not(id: signs.map(&:id)).destroy_all }
          .then(&:size)
      end

      private

        def save_sign(sign_info)
          Sign.find_or_initialize_by(name: sign_info["SignName"])
            .tap { |sign| sign.state = STATE_MAP[sign_info["SignStatus"] || sign_info["AuditStatus"]] || sign.state }
            .tap { |sign| sign.reason = sign_info["Reason"].is_a?(Hash) ? sign_info.dig("Reason", "RejectInfo") : sign_info["Reason"] }
            .tap { |sign| sign.assign_attributes({ created_at: sign_info["CreateDate"] }.compact_blank) }
            .tap(&:save)
        end
    end
  end
end
