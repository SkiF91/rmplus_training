class RmptTestsPagePattern < ActiveRecord::Base
  belongs_to :test, class_name: 'RmptTest', foreign_key: :id, primary_key: :id, inverse_of: :page_pattern, optional: true
end