module Rmpt::Patches::Models
  module GroupSetGlobalPatch
    def self.included(base)
      base.class_eval do
        has_many :rmpt_participants, class_name: 'RmptParticipant', foreign_key: :group_set_id, dependent: :destroy
      end
    end
  end
end