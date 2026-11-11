# frozen_string_literal: true

module Api
  module V1
    # Controller base com error handling unificado para a API REST
    class BaseController < ActionController::API
      rescue_from Routes::RouteNotFoundError, with: :handle_route_not_found
      rescue_from Routes::InvalidAssignmentError, with: :handle_invalid_assignment
      rescue_from Routes::AuditedRouteModificationError, with: :handle_audited_route_modification
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

      protected

      def current_user_uid
        @current_user_uid ||= request.headers['X-User-UID'] || 'anonymous'
      end

      def current_user_name
        @current_user_name ||= request.headers['X-User-Name'] || 'Unknown'
      end

      private

      def handle_route_not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end

      def handle_invalid_assignment(exception)
        render json: { error: exception.message }, status: :unprocessable_entity
      end

      def handle_audited_route_modification(exception)
        render json: { error: exception.message }, status: :unprocessable_entity
      end

      def handle_parameter_missing(exception)
        render json: { error: exception.message }, status: :bad_request
      end
    end
  end
end
