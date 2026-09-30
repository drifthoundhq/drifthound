class ApiToken < ApplicationRecord
  has_secure_token :token

  # Ordered from least to most access: each level includes the ones before it.
  enum :access, { read: "read", read_plans: "read_plans", write: "write" }, prefix: true, validate: true

  ACCESS_LABELS = {
    "read" => "Read only",
    "read_plans" => "Read only, with plan output",
    "write" => "Read and write"
  }.freeze

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  def self.authenticate(token)
    find_by(token: token)
  end

  def self.access_options
    ACCESS_LABELS.map { |access, label| [ label, access ] }
  end

  def read_only?
    !access_write?
  end

  # Plan output can contain sensitive values, so plain read tokens do not get it.
  def can_read_plan_output?
    !access_read?
  end

  def access_label
    ACCESS_LABELS.fetch(access)
  end
end
