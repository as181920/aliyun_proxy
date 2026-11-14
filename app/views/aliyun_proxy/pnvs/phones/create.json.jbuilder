json.phone do
  json.user_id current_user.id
  json.number @phone_number
end
