# RubyEncoder bug
Rails.application.routes.draw do
  get 'rmpt', to: redirect('/rmpt/my/on_me')
  get 'rmpt/my/(:q)', controller: :rmpt, action: :index, as: 'my_rmpt'
  get 'rmpt/:id', controller: :rmpt, action: :prepare, as: 'prepare_rmpt'
  get 'rmpt/:id/processing', controller: :rmpt, action: :processing, as: 'processing_rmpt'
  post 'rmpt/:id/processing', controller: :rmpt, action: :processing
  get 'rmpt/:id/result', controller: :rmpt, action: :result, as: 'result_rmpt'
  get 'rmpt/:id/result_answers', controller: :rmpt, action: :result_answers, as: 'result_answers_rmpt'

  get 'rmpt_reports', controller: :rmpt_reports, action: :report, as: 'rmpt_report'
  post 'rmpt_reports', controller: :rmpt_reports, action: :report

  resources :rmpt_tests do
    collection do
      get 'participants/autocomplete', action: 'participants_autocomplete'
      get 'ajax_users_list'
    end
    member do
      post 'patterns/preview', action: 'patterns_preview'
      post 'participants'
      delete 'participants'
      get 'extra_attempt/(:user_id)', action: 'extra_attempt'
      post 'extra_attempt', action: 'extra_attempt'
      delete 'extra_attempt/:user_id', action: 'extra_attempt'
      post 'import'
    end
  end

  resources :rmpt_categories do
    member do
      post 'move/(:parent_id)', action: 'move'
    end
  end

  resources :rmpt_questions do
    member do
      post 'reorder'
      post 'clear_statistic'
    end
    collection do
      post 'preview'
      patch 'preview'
    end
  end

  resources :group_set_rmpts, controller: 'group_sets', type: 'GroupSetRmpt'
end