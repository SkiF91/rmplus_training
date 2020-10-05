class RmptTestRight < ActiveRecord::Base
  belongs_to :test, class_name: 'RmptTest', foreign_key: :test_id, inverse_of: :rights, optional: true
  belongs_to :user, class_name: 'User', foreign_key: :user_id, optional: true
end