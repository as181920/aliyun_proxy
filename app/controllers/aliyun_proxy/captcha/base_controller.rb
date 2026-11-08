module AliyunProxy
  class Captcha::BaseController < ActionController::Base
    protect_from_forgery with: :exception
    include LocaleGuard

    helper EasyStyle::Engine.helpers
  end
end
