module AliyunProxy
  class Pnvs::BaseController < ApplicationController
    before_action :authenticate
  end
end
