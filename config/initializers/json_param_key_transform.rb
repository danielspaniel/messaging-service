# Transform JSON parameters to use snake_case keys
ActionController::Parameters.action_on_unpermitted_parameters = :raise

# Allow for better parameter handling in development
Rails.application.configure do
  config.action_controller.allow_forgery_protection = false if Rails.env.development?
end
