require 'rmpt/hooks/view_hooks'

require_dependency 'rmpt/menu_items'
require_dependency 'rmpt/utils'
require_dependency 'rmpt/utils/macros/rmpt_user_test_macros'
require_dependency 'rmpt/helpers/menu_helper'

require 'rmpt/patches'
Rmpt::Patches.load_all_dependencies

unless Mime::Type.lookup_by_extension(:xlsx)
  Mime::Type.register "application/vnd.openxmlformates-officedocument.spreadsheetml.sheet", :xlsx
end

Acl::Settings.append_setting('enable_select2_lib', :rmplus_training)
Acl::Settings.append_setting('enable_select2_extensions', :rmplus_training)
Acl::Settings.append_setting('enable_bootstrap_lib', :rmplus_training)
Acl::Settings.append_setting('enable_javascript_patches', :rmplus_training)
Acl::Settings.append_setting('enable_modal_windows', :rmplus_training)
Acl::Settings.append_setting('enable_font_awesome', :rmplus_training)
Acl::Settings.append_setting('enable_ajax_counters', :rmplus_training)