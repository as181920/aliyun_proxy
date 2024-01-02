module AliyunProxy
  module AuthGuard
    extend ActiveSupport::Concern

    InvalidAuthTypeError = Class.new(StandardError)
    InvalidAuthValueError = Class.new(StandardError)
    AuthenticateFailError = Class.new(StandardError)

    SUPPORTED_AUTH_TYPES = ["PlainUserCode", "PlainUserToken", "Basic"].freeze

    included do
      helper_method :current_user

      rescue_from AuthenticateFailError, InvalidAuthTypeError, InvalidAuthValueError, with: :handle_authenticate_failure
      rescue_from Pundit::NotAuthorizedError, with: :handle_authorize_failure
    end

    module ClassMethods
    end

    private

      def authenticate
        raise AuthenticateFailError, "authenticate failed." unless current_user.present?
      end

      def current_user
        @current_user ||= auth_params.present? ? authenticate_user : session_user
      end

      def session_user
        user_model&.find_by(id: session[:usr_user_id])
      end

      def authenticate_user
        send(:"authenticate_using_#{auth_params[:type].underscore}", auth_params[:value])&.tap { |u| session[:usr_user_id] = u.id }
      end

      def authenticate_using_basic(_credentials)
        session_user
      end

      def authenticate_using_plain_user_code(code_value)
        credential_model&.find_by(code: code_value)&.tap(&:regenerate_code)&.user
      end

      def authenticate_using_plain_user_token(token_value)
        credential_model&.find_by(token: token_value)&.user
      end

      def auth_params
        @auth_params ||= auth_params_from_url || auth_params_from_header
      end

      def auth_params_from_header
        return if request.authorization.blank?

        ActiveSupport::HashWithIndifferentAccess.new.tap { |p| p[:type], p[:value] = request.authorization&.split }.tap do |p|
          raise(InvalidAuthTypeError, "auth type not supported.") if SUPPORTED_AUTH_TYPES.exclude?(p[:type])
          raise(InvalidAuthValueError, "auth value is blank.") if p[:value].blank?
        end
      end

      def auth_params_from_url
        p_key = [:auth_code, :auth_token].detect { |k| request.query_parameters[k].present? }
        { type: { auth_code: "PlainUserCode", auth_token: "PlainUserToken" }[p_key], value: request.query_parameters[p_key] } if p_key.present?
      end

      def user_model
        ["UserAuth::User"].detect(&:safe_constantize)&.safe_constantize
      end

      def credential_model
        ["UserAuth::User::Credential"].detect(&:safe_constantize)&.safe_constantize
      end

      def handle_authenticate_failure(error)
        logger.warn "#{error.class.name}: #{error.message}"
        respond_to do |format|
          format.html { render plain: "用户认证失败。", status: :unauthorized }
          format.json { render json: { error: { message: "#{error.class.name}: #{error.message}" } }, status: :unauthorized }
        end
      end

      def handle_authorize_failure(_error)
        respond_to do |format|
          format.html { render plain: "权限不足，请联系管理员。", status: :forbidden }
          format.json { head :forbidden }
        end
      end
  end
end
