class Api::BaseController < ApplicationController
  # Rails processes rescue_from in reverse order, so put general ones first
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ArgumentError, with: :handle_argument_error
  rescue_from MessageProviderService::ProviderError, with: :handle_provider_error
  rescue_from MessageProviderService::ServerError, with: :handle_server_error
  rescue_from MessageProviderService::RateLimitError, with: :handle_rate_limit_error
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  
  private
  
  def handle_standard_error(exception)
    Rails.logger.error "#{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render json: { error: 'Internal server error', message: exception.message }, status: :internal_server_error
  end
  
  def handle_not_found(exception)
    render json: { error: 'Not found', message: exception.message }, status: :not_found
  end
  
  def handle_validation_error(exception)
    render json: { 
      error: 'Validation failed', 
      message: exception.message,
      details: exception.record.errors.full_messages
    }, status: :unprocessable_content
  end
  
  def render_success(data = {}, status = :ok)
    render json: { success: true, data: data }, status: status
  end
  
  def render_error(message, status = :bad_request, details = nil)
    response = { success: false, error: message }
    response[:details] = details if details
    render json: response, status: status
  end
  
  def handle_rate_limit_error(exception)
    Rails.logger.info "HANDLING RATE LIMIT ERROR: #{exception.class}"
    render json: { 
      error: 'Rate limit exceeded', 
      message: exception.message,
      retry_after: 60 # seconds
    }, status: 429
  end
  
  def handle_server_error(exception)
    render json: { 
      error: 'Provider server error', 
      message: exception.message 
    }, status: 502 # Bad Gateway
  end
  

  
  def handle_provider_error(exception)
    Rails.logger.info "HANDLING PROVIDER ERROR: #{exception.class}"
    render json: { 
      error: 'Provider error', 
      message: exception.message 
    }, status: exception.status_code
  end
  
  def handle_argument_error(exception)
    render json: { 
      error: 'Invalid request', 
      message: exception.message 
    }, status: :bad_request
  end
end
