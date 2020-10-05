module Rmpt::Utils
  module Macros
    class RmptUserMacros < Acl::Utils::Macros::BaseMacros
      def target_class
        ::RmptUserTest
      end

      def fill_macros
        super
        macros_list.add('user_test.q_count_total', :label_rmpt_macros_q_count_total, :fields, Proc.new { |tst|
          rmp_number_text(tst.q_count_total.to_s) + l(:rmpt_label_question_with_count, count: tst.q_count_total)
        })
        macros_list.add('user_test.q_res_count_total', :label_rmpt_macros_q_res_count_total, :fields, :q_count_total)
        macros_list.add('user_test.min_pass', :label_rmpt_macros_min_pass, :fields, Proc.new { |tst|
          rmp_number_text(tst.min_pass_text.to_i.to_s) + "#{'%' if tst.min_pass_percent.present?}" + l(:rmpt_label_question_with_count, count: tst.min_pass_text)
        })
        macros_list.add('user_test.timelimit', :label_rmpt_macros_timelimit, :fields, Proc.new { |tst|
          if tst.timelimit_q.present?
            Rmpt::Utils.convert_seconds_to_time_string(tst.timelimit_q)
          elsif tst.timelimit_total.present?
            Rmpt::Utils.convert_seconds_to_time_string(tst.timelimit_total)
          else
            l(:label_rmpt_test_timelimit_unlimit)
          end
        })
        macros_list.add('user_test.attempts', :field_rmpt_test_attempts, :fields, Proc.new { |tst|
          rmp_number_text(tst.test.total_attempts(tst.user), l(:label_rmpt_test_attempts_unlimit))
        })
        macros_list.add('user_test.attempts_left', :label_rmpt_macros_attempts_left, :fields, Proc.new { |tst|
          if tst.attempts.blank?
            rmp_number_text(nil, l(:label_rmpt_test_attempts_unlimit))
          else
            rmp_number_text(tst.test.total_attempts(tst.user) - tst.test.user_attempts(tst.user).where('start_at is not null').size, l(:label_rmpt_test_attempts_unlimit))
          end
        })
        macros_list.add('user_test.attempts_used', :label_rmpt_macros_attempts_used, :fields, Proc.new { |tst|
          rmp_number_text(tst.test.user_attempts(tst.user).where('start_at is not null').size)
        })

        macros_list.add('user_test.due', :label_rmpt_macros_due, :fields, Proc.new { |tst|
          if tst.due.present?
            format_date(tst.due)
          else
            l(:label_rmpt_test_due_unlimit)
          end
        })
        macros_list.add('user_test.q_count_correct', :label_rmpt_macros_q_count_correct, :fields, Proc.new { |tst|
          rmp_number_text(tst.q_count_correct.to_s) + l(:rmpt_label_question_with_count, count: tst.q_count_correct)
        })
        macros_list.add('user_test.q_result_ratio', :label_rmpt_macros_q_result_ratio, :fields, Proc.new { |tst|
          rmp_number_text(tst.result_ratio) + '%'
        })
      end
    end
  end
end