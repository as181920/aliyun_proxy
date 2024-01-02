AliyunProxy::Engine.routes.draw do
  get "welcome/index"
  root "welcome#index"

  namespace :sms do
    namespace :callback do
      resources :up_messages, only: [:create]
      resources :sign_reports, only: [:create]
      resources :template_reports, only: [:create]
      resources :message_reports, only: [:create]
    end
  end

  namespace :pnvs do # Phone Number Verification Service
    resources :auth_tokens, only: [:create]
    resources :phones, only: [:create]
  end
end
