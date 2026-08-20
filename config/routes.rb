Rails.application.routes.draw do
  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]
  resource :registration, only: %i[ new create ]

  resources :tournaments do
    member do
      post :start
    end
  end

  resources :matches, only: [] do
    resource :report, only: %i[ create ]
  end

  resources :users, only: %i[ index show update ]

  get "about" => "home#about", as: :about
  get "my_match" => "home#my_match", as: :my_match

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
