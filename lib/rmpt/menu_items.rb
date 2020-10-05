module Rmpt::MenuItems
  def self.my_tests_actual_caption
    res = "<span>#{I18n.t(:label_rmpt_top_menu_my_tests)}</span>"
    res << User.current.acl_ajax_counter('rmpt_tests_count' , { period: 600, params: { q: 'actual' } })

    res.html_safe
  end
end