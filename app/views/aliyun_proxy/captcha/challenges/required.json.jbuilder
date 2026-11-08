json.error do
  json.code "captcha.required"
  json.message t("aliyun_proxy.captcha.required")
end
json.challenge_url @captcha_challenge_url
