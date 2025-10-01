require "sidekiq/web"

Rails.application.routes.draw do
  get "tickets/index"
  get "tickets/push"
  get "tickets/poll"
  get "users/new"
  resources :passwords, param: :token

  # Authentication
  get :login, to: "sessions#new", as: :login
  post :login, to: "sessions#create"
  get :logout, to: "sessions#destroy", as: :logout

  get :signup, to: "users#new", as: :signup
  post :signup, to: "users#create"

  # OAuth
  post "/auth/google_oauth2", as: :google_oauth2
  get "/auth/:provider/callback", to: "omniauth#callback"

  # Gmail poller
  get "/tickets-poll", to: "tickets#index_with_poll", as: :tickets_polling
  get "/tickets-pubsub", to: "tickets#index_with_pubsub", as: :tickets_pubsub
  post "/tickets/push", to: "tickets#push", as: :mail_push
  get "/tickets/poll", to: "tickets#poll", as: :mail_poll

  mount Sidekiq::Web => "/sidekiq" # mount Sidekiq::Web in your Rails app

  resources :tickets do
    post :reply, on: :member
    collection do
      patch :toggle_gmail_watch
    end
  end

  root "home#index"
end
