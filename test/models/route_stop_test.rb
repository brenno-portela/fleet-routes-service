# frozen_string_literal: true

require 'test_helper'

class RouteStopTest < Minitest::Test
  def setup
    @route = Route.create!(
      name: 'Rota Teste Paradas',
      seller_uid: 'seller_test',
      status: Route::STATUS_ASSIGNED
    )
    @valid_stop_attributes = {
      route: @route,
      customer_id: 'cust_101',
      customer_name: 'Supermercado Central',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_ASSIGNED
    }
  end

  def test_valid_stop_creation
    stop = RouteStop.new(@valid_stop_attributes)
    assert stop.valid?
    assert stop.save
  end

  def test_validates_presence_of_mandatory_attributes
    stop = RouteStop.new
    refute stop.valid?
    assert_includes stop.errors[:customer_id], "can't be blank"
    assert_includes stop.errors[:customer_name], "can't be blank"
    assert_includes stop.errors[:latitude], "can't be blank"
    assert_includes stop.errors[:longitude], "can't be blank"
    assert_includes stop.errors[:order], "can't be blank"
  end

  def test_order_uniqueness_scoped_to_route
    RouteStop.create!(@valid_stop_attributes)

    duplicate_order_stop = RouteStop.new(
      @valid_stop_attributes.merge(customer_id: 'cust_102', customer_name: 'Outro')
    )
    refute duplicate_order_stop.valid?
    assert_includes duplicate_order_stop.errors[:order], 'has already been taken'
  end

  def test_coordinates_must_be_geographically_valid
    invalid_stop = RouteStop.new(@valid_stop_attributes.merge(latitude: 0, longitude: 0))
    refute invalid_stop.valid?
    assert_includes invalid_stop.errors[:coordinates], 'devem ser uma latitude e longitude terrestres válidas e não nulas'
  end

  def test_cannot_exceed_max_stops_limit_of_24
    24.times do |i|
      @route.route_stops.create!(
        customer_id: "c_#{i}",
        customer_name: "Cliente #{i}",
        latitude: -23.55,
        longitude: -46.63,
        order: i + 1,
        status: RouteStop::STATUS_ASSIGNED
      )
    end

    assert_equal 24, @route.route_stops.count

    excess_stop = @route.route_stops.build(
      customer_id: 'c_25',
      customer_name: 'Cliente 25',
      latitude: -23.55,
      longitude: -46.63,
      order: 25,
      status: RouteStop::STATUS_ASSIGNED
    )
    refute excess_stop.valid?
    assert_includes excess_stop.errors[:base], 'Uma rota aceita no máximo 24 clientes.'
  end

  def test_recorded_execution_detection
    stop = RouteStop.create!(@valid_stop_attributes)
    refute stop.recorded_execution?

    # Check-in registrado
    stop.check_in_at = Time.now
    assert stop.recorded_execution?

    # Ou feedback gravado
    stop.check_in_at = nil
    stop.feedback = 'Cliente não estava no local'
    assert stop.recorded_execution?

    # Ou attendance registrado
    stop.feedback = nil
    stop.stop_attendances.create!(
      check_in_at: Time.now,
      status: StopAttendance::STATUS_IN_PROGRESS
    )
    assert stop.recorded_execution?
  end
end

