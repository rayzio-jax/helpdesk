class OmniauthController < ApplicationController
  allow_unauthenticated_access only: %i[ callback ]

  def callback
    auth = request.env["omniauth.auth"]
    user_info = auth["info"]
    creds = auth["credentials"]

    begin
      user = User.find_or_create_by!(email_address: auth["info"]["email"]) do |u|
        u.name = user_info["name"]
        u.email_address = user_info["email"]
        u.password = SecureRandom.hex(15)
        u.image_url = user_info["image"]
      end

      Account.find_or_create_by!(user: user, provider: auth["provider"], uid: auth["uid"]) do |a|
        a.access_token = creds["token"]
        a.refresh_token = creds["refresh_token"]
        a.expires_at = creds["expires_at"] ? Time.at(creds["expires_at"]) : nil
      end

      start_new_session_for user
      redirect_to after_authentication_url
    rescue ActiveRecord::RecordInvalid => e
      redirect_to login_path, alert: "Google authentication failed, #{e.message}"
    end
  end
end
