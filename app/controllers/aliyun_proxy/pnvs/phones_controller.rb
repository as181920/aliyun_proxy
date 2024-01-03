module AliyunProxy
  class Pnvs::PhonesController < Pnvs::BaseController
    after_action :bind_user_phone, only: %i[create]

    def create
      @phone_number = Pnvs::PhoneService.new(
        (ENV.fetch("aliyun_pnvs_access_key_id", nil) || ENV.fetch("aliyun_access_key_id", nil)),
        (ENV.fetch("aliyun_pnvs_access_key_secret", nil) || ENV.fetch("aliyun_access_key_secret", nil))
      ).get_number(sp_token: phone_params[:sp_token])&.dig("Data", "Mobile")

      if @phone_number.present?
        render json: { phone: { user_id: current_user.id, number: @phone_number } }, status: :ok
      else
        render json: { error: { message: "Mobile phone number not detected." } }, status: :bad_request
      end
    end

    private

      def phone_params
        params.fetch(:phone, {}).permit :sp_token
      end

      def bind_user_phone
        return if @phone_number.blank?

        if current_user.respond_to?(:phone)
          current_user.phone.model.find_or_create_by(number: @phone_number).update(user: current_user)
        elsif user.respond_to?(:phones)
          current_user.phones.model.find_or_create_by(number: @phone_number).update(user: current_user)
        end
      end
  end
end
