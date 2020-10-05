module Rmpt::Patches::Models
  module UserPatch
    def self.included(base)
      base.send :include, InstanceMethods

      base.class_eval do
        has_many :rmpt_test_rights, class_name: 'RmptTestRight', foreign_key: :user_id, dependent: :destroy
        has_many :rmpt_tests, class_name: 'RmptTest', foreign_key: :author_id
        has_many :rmpt_user_tests, class_name: 'RmptUserTest', foreign_key: :user_id, dependent: :destroy
        has_many :rmpt_extra_attempt, class_name: 'RmptExtraAttempt', foreign_key: :user_id, dependent: :destroy
      end
    end

    module InstanceMethods
      def rmpt_tests_count(view_context=nil, params=nil, session=nil)
        if params.present? && params[:q].present?
          RmptTest.my_filtered(User.current, params[:q].to_s).size
        else
          RmptTest.my_filtered(User.current, 'on_me').size
        end
      end
    end
  end
end