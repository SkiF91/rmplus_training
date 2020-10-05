Redmine::Plugin.register :rmplus_training do
  name 'RMPlus Training plugin'
  author 'Kovalevsky Vasil'
  description 'This is a plugin for Redmine'
  version '1.0.0'
  url 'http://rmplus.pro/'
  author_url 'http://rmplus.pro/'

  requires_redmine '4.0.0'

  menu :top_menu, :rmpt_my_tests, :rmpt_my_tests_actual, caption: Proc.new { Rmpt::MenuItems.my_tests_actual_caption }, if: Proc.new { User.current.logged? }, html: { class: 'no_line' }

  project_module :rmplus_training do
    permission :rmpt_manage_tests, {
      rmpt_tests: [:index, :new, :edit, :create, :update, :destroy, :patterns_preview, :participants, :ajax_users_list, :extra_attempt, :import],
      rmpt_questions: [:new, :edit, :create, :update, :destroy, :reorder, :preview],
      rmpt_reports: [:report]
    }
    permission :rmpt_view_all_tests, {}
    permission :rmpt_manage_categories, rmpt_categories: [:index, :new, :edit, :create, :update, :destroy, :move]
  end
  # settings partial: 'rmplus_training/settings', default: {}
end

Rails.application.config.to_prepare do
  load 'rmpt/loader.rb'
end

Rails.application.config.after_initialize do
  plugins = { a_common_libs: '2.5.4', global_roles: '2.2.5', ldap_users_sync: '2.7.2' }
  plugin = Redmine::Plugin.find(:rmplus_training)
  plugins.each do |k,v|
    begin
      plugin.requires_redmine_plugin(k, v)
    rescue Redmine::PluginNotFound => ex
      raise(Redmine::PluginNotFound, "Plugin requires #{k} not found")
    end
  end
end