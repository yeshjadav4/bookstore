require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  mount Sidekiq::Web => "/sidekiq"

  root "books#index"

  resources :books, only: [:index, :show] do
    collection do
      get :export
    end
  end

  namespace :admin do
    resources :books do
      resources :book_images, only: [:index, :destroy]
    end
    resources :scraping_urls do
      member do
        post :toggle_active
        post :scrape_now
      end
      collection do
        post :scrape_all
      end
    end
    resources :scrape_logs, only: [:index]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
