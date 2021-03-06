Rails.application.routes.draw do
  root 'crawlers#index'

  devise_for :admin_users

  resources :crawlers, only: [:index, :show] do
    member do
      get  'import'
      post 'upload' # upload edited crawler version snapshot
      get  'duplicate_courses'

      post 'setting'
      post 'run'
      post 'sync'
    end

    resources :tasks, only: [], controller: 'crawl_tasks' do
      member do
        get  'changes'
        post 'snapshot'
      end
    end

    resources :jobs, only: [:destroy], controller: 'crawlers'

    collection do
      post 'batch_run'
    end
  end

  resources :courses, only: [:index] do
    collection do
      post 'download'
    end
  end

  # Sidekiq
  require 'sidekiq/web'
  authenticate :admin_user do
    mount Sidekiq::Web => '/sidekiq'
  end

end
