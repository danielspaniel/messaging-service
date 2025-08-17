Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    # Message sending endpoints
    scope :messages do
      post :sms, to: 'messages#send_sms'
      post :email, to: 'messages#send_email'
    end
    
    # Webhook endpoints for receiving messages
    scope :webhooks do
      post :sms, to: 'webhooks#receive_sms'
      post :email, to: 'webhooks#receive_email'
    end
    
    # Conversation management
            resources :conversations, only: [:index, :show] do
          member do
            get :messages
          end
        end
        
        resources :messages, only: [:show] do
          member do
            get :status
          end
        end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
