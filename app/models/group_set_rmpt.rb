class GroupSetRmpt < GroupSet
  has_one :test, class_name: 'RmptTest', foreign_key: :group_set_id, inverse_of: :group_set

  def has_access?
    self.test.manageable?
  end
end