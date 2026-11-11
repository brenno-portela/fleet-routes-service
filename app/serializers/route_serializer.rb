# frozen_string_literal: true

# Serializador PORO para rotas com suporte a renderização detalhada e resumida
class RouteSerializer
  def self.render(route, detailed: false)
    new(route, detailed: detailed).to_h
  end

  def initialize(route, detailed: false)
    @route = route
    @detailed = detailed
  end

  def to_h
    base_attributes.tap do |attrs|
      attrs[:stops] = serialize_stops if @detailed
      attrs[:attendances] = serialize_attendances if @detailed
      attrs[:telemetry] = serialize_telemetry if @detailed
    end
  end

  private

  def base_attributes
    {
      id: @route.id,
      name: @route.name,
      seller_uid: @route.seller_uid,
      seller_name: @route.seller_name,
      seller_email: @route.seller_email,
      status: @route.status,
      due_date: @route.due_date&.strftime('%Y-%m-%d'),
      target_completion_percent: @route.target_completion_percent,
      target_completed_stops: @route.target_completed_stops,
      state: @route.state,
      assignment_notes: @route.assignment_notes,
      estimated_distance_meters: @route.estimated_distance_meters,
      estimated_duration_seconds: @route.estimated_duration_seconds,
      stops_count: @route.route_stops.count,
      visited_stops_count: @route.route_stops.count { |s| s.status == RouteStop::STATUS_VISITED },
      completion_percent: @route.completion_percent,
      created_at: @route.created_at&.iso8601,
      updated_at: @route.updated_at&.iso8601
    }
  end

  def serialize_stops
    @route.route_stops.ordered.map do |stop|
      {
        id: stop.id,
        order: stop.order,
        customer_id: stop.customer_id,
        customer_name: stop.customer_name,
        cnpj_cpf: stop.cnpj_cpf,
        address: stop.address,
        city: stop.city,
        state: stop.state,
        phone: stop.phone,
        email: stop.email,
        latitude: stop.latitude,
        longitude: stop.longitude,
        status: stop.status,
        check_in_at: stop.check_in_at&.iso8601,
        check_out_at: stop.check_out_at&.iso8601,
        feedback: stop.feedback,
        not_visited_reason: stop.not_visited_reason,
        visit_duration_seconds: stop.visit_duration_seconds
      }
    end
  end

  def serialize_attendances
    @route.stop_attendances.map do |attendance|
      {
        id: attendance.id,
        route_stop_id: attendance.route_stop_id,
        check_in_at: attendance.check_in_at&.iso8601,
        check_out_at: attendance.check_out_at&.iso8601,
        status: attendance.status,
        visit_duration_seconds: attendance.visit_duration_seconds
      }
    end
  end

  def serialize_telemetry
    calculator = Routes::TelemetryCalculator
    {
      total_visit_duration_seconds: calculator.total_visit_duration_seconds(@route),
      average_visit_duration_seconds: calculator.average_visit_duration_seconds(@route),
      completion_percentage: calculator.completion_percentage(@route),
      feedback_coverage_percentage: calculator.feedback_coverage_percentage(@route)
    }
  end
end
