class RmptExtraAttempt < ActiveRecord::Base
  belongs_to :test, class_name: 'RmptTest', foreign_key: :test_id, optional: true
  belongs_to :user, optional: true

  validates :test_id, :user_id, presence: true
  validates_uniqueness_of :test_id, scope: :user_id

  scope :sorted, -> {
    joins(:user).order(User.fields_for_order_statement)
  }
end