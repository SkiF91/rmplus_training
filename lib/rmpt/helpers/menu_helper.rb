module Rmpt::Helpers
  module MenuHelper
    def rmpt_my_tests_actual
      url_for controller: :rmpt, action: :index, q: 'actual'
    end
  end
end

ActionView::Base.send(:include, Rmpt::Helpers::MenuHelper)