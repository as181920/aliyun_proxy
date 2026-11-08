module AliyunProxy
  module LocaleGuard
    extend ActiveSupport::Concern

    included do
      around_action :switch_locale
    end

    def default_url_options
      super.merge(locale: I18n.locale)
    end

    private

      def switch_locale(&block)
        locale = params[:locale].to_s.presence_in(I18n.available_locales.map(&:to_s)) ||
          AcceptLanguage.parse(request.headers["Accept-Language"].to_s).match(*I18n.available_locales) ||
          I18n.default_locale
        I18n.with_locale(locale, &block)
      end
  end
end
