class RmptParticipant < ActiveRecord::Base
  belongs_to :test, class_name: 'RmptTest', foreign_key: :test_id, optional: true
  belongs_to :group_set, class_name: 'GroupSetGlobal', foreign_key: :group_set_id, optional: true
end