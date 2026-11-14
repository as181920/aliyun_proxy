module AliyunProxy
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    include AuthGuard
  end
end
