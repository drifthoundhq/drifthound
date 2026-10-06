class EnvironmentPolicy < ApplicationPolicy
  def show?
    true
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end

  def view_plan?
    minimum = Rails.application.config.plan_output_min_role.to_s
    return true if minimum == "viewer"
    return false unless user

    User.roles.fetch(user.role) >= User.roles.fetch(minimum)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
