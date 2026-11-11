# frozen_string_literal: true

module Api
  module V1
    # Controller para endpoints CRUD de rotas
    class RoutesController < BaseController
      def index
        limit = params[:limit].to_i.clamp(1, 200) || 50
        filters = build_filter_params

        routes = Route.includes(:route_stops, :stop_attendances, :visit_events)
                      .recent(limit)

        # Aplicar filtros
        routes = routes.by_status(filters[:status]) if filters[:status].present?
        routes = routes.by_seller(filters[:seller_uid]) if filters[:seller_uid].present?
        routes = routes.by_state(filters[:state]) if filters[:state].present?

        # Filtro por data
        if filters[:date_from].present?
          routes = routes.where('routes.due_date >= ?', parse_date(filters[:date_from]))
        end
        if filters[:date_to].present?
          routes = routes.where('routes.due_date <= ?', parse_date(filters[:date_to]))
        end

        # Filtro por busca
        if filters[:search].present?
          search_term = "%#{filters[:search]}%"
          routes = routes.where(
            'routes.name ILIKE ? OR EXISTS (SELECT 1 FROM route_stops WHERE route_stops.route_id = routes.id AND route_stops.customer_name ILIKE ?)',
            search_term,
            search_term
          )
        end

        serialized = routes.map { |route| RouteSerializer.render(route, detailed: false) }
        render json: serialized, status: :ok
      end

      def show
        route = Route.find(params[:id])
        serialized = RouteSerializer.render(route, detailed: true)
        render json: serialized, status: :ok
      end

      def update
        route = Route.find(params[:id])
        update_params = build_update_params

        Routes::UpdateAssignment.call(
          route: route,
          seller_uid: update_params[:seller_uid],
          seller_name: update_params[:seller_name],
          seller_email: update_params[:seller_email],
          due_date: update_params[:due_date],
          name: update_params[:name],
          target_completion_percent: update_params[:target_completion_percent],
          notes: update_params[:notes],
          customers: update_params[:customers] || [],
          estimate: update_params[:estimate],
          current_user_uid: current_user_uid,
          current_user_name: current_user_name
        )

        serialized = RouteSerializer.render(route.reload, detailed: true)
        render json: serialized, status: :ok
      end

      def destroy
        route = Route.find(params[:id])
        Routes::DeleteRoute.call(route)

        render json: { success: true, message: 'Rota excluída com sucesso.' }, status: :ok
      end

      private

      def build_filter_params
        params.permit(:status, :seller_uid, :state, :date_from, :date_to, :search).to_h.symbolize_keys
      end

      def build_update_params
        params.require(:route).permit(
          :name, :seller_uid, :seller_name, :seller_email, :due_date,
          :target_completion_percent, :notes,
          customers: [:customer_id, :customer_name, :latitude, :longitude, :address, :phone_number, :email],
          estimate: [:distance_meters, :duration_seconds]
        ).to_h.symbolize_keys
      end

      def parse_date(date_value)
        return date_value if date_value.is_a?(Date)
        return date_value.to_date if date_value.is_a?(Time)

        Date.parse(date_value.to_s)
      end
    end
  end
end
