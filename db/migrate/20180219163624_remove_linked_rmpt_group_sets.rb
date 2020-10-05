class RemoveLinkedRmptGroupSets < ActiveRecord::Migration[4.2]
  def down
    if ActiveRecord::Base.connection.table_exists?('group_sets')
      GroupSet.where(type: 'GroupSetRmpt').delete_all
    end
  end
end