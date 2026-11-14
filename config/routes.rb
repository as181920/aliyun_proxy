AliyunProxy::Engine.routes.draw do
  get "welcome/index"

  get "api-docs/openapi.json", to: "captcha/api_docs#show", as: :openapi_spec
  get "api-docs/openapi/:role.json", to: "api_docs#show", as: :role_openapi_spec

  namespace :captcha do
    resource :login_verification, only: :show
    resources :challenges, only: %i[show update]
  end
  root "welcome#index"

  namespace :sms do
    namespace :callback do
      resources :up_messages, only: %i[index create]
      resources :sign_reports, only: %i[index create]
      resources :template_reports, only: %i[index create]
      resources :message_reports, only: %i[index create]
    end
  end

  namespace :pnvs do # Phone Number Verification Service
    resources :auth_tokens, only: [:create]
    resources :phones, only: [:create]
  end
end
