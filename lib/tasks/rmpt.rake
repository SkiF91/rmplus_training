# encoding: utf-8
namespace :redmine do
  namespace :rmpt do
    task complete_expired: :environment do
      RmptUserTest.expired
                  .joins("LEFT JOIN (
                            SELECT q.test_id,
                                   COUNT(1) as cnt
                            FROM #{RmptUserQuestion.table_name} q
                            WHERE q.correct = #{RmptTest.connection.quoted_true}
                            GROUP BY q.test_id
                          ) q ON q.test_id = #{RmptUserTest.table_name}.id
                         ")
                  .select("#{RmptUserTest.table_name}.*, q.cnt / #{RmptUserTest.table_name}.q_count_total * 100 as calc_result_ratio")
                  .each do |ut|
        RmptUserTest.where(id: ut.id).update_all(expired: true, completed: true, passed: ut.passed?, result_ratio: ut.attributes['calc_result_ratio'], status: ut.passed? ? RmptUserTest::STATUS_SUCCESS : RmptUserTest::STATUS_TIMELIMIT_EXPIRED)
      end

      RmptUserQuestion.expired.where("#{RmptUserQuestion.table_name}.expired IS NULL").update_all(["#{RmptUserQuestion.table_name}.completed = ?, #{RmptUserQuestion.table_name}.expired = ?", true, true])
    end
  end
end