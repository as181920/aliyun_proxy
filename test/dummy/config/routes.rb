Rails.application.routes.draw do
  mount AliyunProxy::Engine => "/aliyun_proxy"
end
