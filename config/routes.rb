Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # API routes
  namespace :api do
    namespace :v1 do
      # Write endpoint (existing)
      post "projects/:project_key/environments/:environment_key/checks", to: "drift_checks#create", as: :environment_checks

      # Read endpoints (new)
      resources :projects, only: [ :index, :show ], param: :key do
        resources :environments, only: [ :index, :show ], param: :key do
          member do
            get :drift
          end
        end
      end
    end
  end

  # Session routes
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # OAuth routes
  get "auth/github", to: "oauth_callbacks#github_redirect", as: :auth_github
  get "auth/github/callback", to: "oauth_callbacks#github", as: :auth_github_callback

  # Registration via invite
  get "register/:token", to: "registrations#new", as: :register
  post "register/:token", to: "registrations#create"

  # User management (admin only)
  resources :users, except: [ :show ]

  # Invite management (admin only)
  resources :invites, only: [ :create, :destroy ]

  # API token management (admin only)
  resources :api_tokens, only: [ :index, :create, :destroy ]

  # Dashboard routes
  root "dashboard#index"
  get "projects/:key", to: "projects#show", as: :project
  delete "projects/:key", to: "projects#destroy"
  get "projects/:project_key/environments/:key", to: "environments#show", as: :project_environment
  delete "projects/:project_key/environments/:key", to: "environments#destroy"
end
