module AliyunProxy
  module Captcha
    module BrowserBinding
      class << self
        def key(session)
          session[:aliyun_captcha_browser_key] ||= SecureRandom.urlsafe_base64(32)
        end
      end
    end
  end
end
