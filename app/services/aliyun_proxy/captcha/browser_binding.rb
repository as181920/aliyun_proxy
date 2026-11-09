require "digest"

module AliyunProxy
  module Captcha
    module BrowserBinding
      class << self
        def key(session, create: true)
          session.update({}) if create && session.id.nil?
          id = session.id&.public_id
          Digest::SHA256.hexdigest("aliyun_proxy:browser:#{id}") if id.present?
        end
      end
    end
  end
end
