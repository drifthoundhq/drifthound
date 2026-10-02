module Oauth
  class OidcService
    PROVIDER = "oidc"

    class EmailTakenError < BaseService::OauthError; end

    def initialize(auth)
      @auth = auth
    end

    def authenticate
      uid = @auth&.uid.to_s
      raise BaseService::UserInfoError, "No subject returned by the identity provider" if uid.blank?

      role = determine_role
      user = User.find_by(provider: PROVIDER, uid: uid)

      if user
        user.update!(role: role)
        user
      else
        create_user(uid, role)
      end
    end

    private

    def config
      Rails.application.config.oidc
    end

    def raw_info
      @auth.extra&.raw_info || {}
    end

    def groups
      Array(raw_info[config[:groups_claim]]).flatten.map(&:to_s)
    end

    def determine_role
      user_groups = groups
      matched = config[:group_mappings].select { |_, names| (names & user_groups).any? }.keys
      role = matched.max_by { |r| BaseService::ROLE_PRIORITY[r] || -1 } || config[:default_role]

      raise BaseService::OrganizationAccessError, "User is not a member of any configured group" if role.nil?

      role
    end

    def create_user(uid, role)
      email = @auth.info&.email.to_s.strip.downcase
      raise BaseService::UserInfoError, "No email returned by the identity provider" if email.blank?
      raise BaseService::UserInfoError, "Email is not verified by the identity provider" if raw_info["email_verified"].to_s == "false"
      raise EmailTakenError, "Email belongs to another account" if User.where("LOWER(email) = ?", email).exists?

      User.create!(email: email, provider: PROVIDER, uid: uid, role: role)
    end
  end
end
