module AliyunProxy
  module Sms
    class TemplateService < ApiBaseService
      STATE_MAP = {
        AUDIT_STATE_INIT: :approving,
        AUDIT_STATE_PASS: :approved,
        AUDIT_STATE_NOT_PASS: :rejected,
        AUDIT_STATE_CANCEL: :cancelled,
        0 => :approving,
        1 => :approved,
        2 => :rejected
      }.with_indifferent_access.freeze

      QUERY_TYPE_MAP = {
        0 => :verification_code,
        1 => :notification,
        2 => :promotion,
        3 => :international,
        7 => :digital
      }.freeze

      LIST_TYPE_MAP = {
        0 => :notification,
        1 => :promotion,
        2 => :verification_code,
        6 => :international,
        7 => :digital
      }.freeze

      def add
      end

      def modify
      end

      def delete(template_code)
        api_client.delete_template(template_code)
      end

      def query(template_code)
        api_client.query_template(template_code)
      end

      def sync_template(template_code)
        query(template_code).then { |info| save_template(info, type_map: QUERY_TYPE_MAP) }
      end

      def list(page: 1, per: 10)
        api_client.query_template_list(page:, per:)
      end

      def sync_list
        template_infos = []

        (1..).each do |page|
          page_infos = Array(list(page:)["SmsTemplateList"])
          page_infos.present? ? template_infos.concat(page_infos) : break
        end

        template_infos
          .sort_by { |info| info["CreateDate"] }
          .map { |info| save_template(info, type_map: LIST_TYPE_MAP) }
          .tap { |templates| Sign.where.not(id: templates.map(&:id)).destroy_all }
          .then(&:size)
      end

      private

        def save_template(info, type_map:)
          Template.find_or_initialize_by(template_code: info["TemplateCode"])
            .tap { |tmpl| tmpl.state = STATE_MAP[info["TemplateStatus"] || info["AuditStatus"]] || tmpl.state }
            .tap { |tmpl| tmpl.message_type = type_map[info["TemplateType"]] }
            .tap { |tmpl| tmpl.reason = info["Reason"].is_a?(Hash) ? info.dig("Reason", "RejectInfo") : info["Reason"] }
            .tap { |tmpl| tmpl.assign_attributes({ name: info["TemplateName"], content: info["TemplateContent"], created_at: info["CreateDate"] }.compact_blank) }
            .tap(&:save!)
        end
    end
  end
end
