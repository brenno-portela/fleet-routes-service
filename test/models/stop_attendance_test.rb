# frozen_string_literal: true

require 'test_helper'

class StopAttendanceTest < Minitest::Test
  def setup
    @route = Route.create!(
      name: 'Rota Teste Atendimento',
      seller_uid: 'seller_test',
      status: Route::STATUS_ASSIGNED
    )
    @stop = @route.route_stops.create!(
      customer_id: 'cust_201',
      customer_name: 'Farmácia Saúde',
      latitude: -23.55,
      longitude: -46.63,
      order: 1,
      status: RouteStop::STATUS_ASSIGNED
    )
  end

  def test_valid_attendance_creation
    attendance = @stop.stop_attendances.new(
      check_in_at: Time.now,
      status: StopAttendance::STATUS_IN_PROGRESS
    )
    assert attendance.valid?
    assert attendance.save
  end

  def test_requires_check_in_at
    attendance = @stop.stop_attendances.new(status: StopAttendance::STATUS_IN_PROGRESS)
    refute attendance.valid?
    assert_includes attendance.errors[:check_in_at], "can't be blank"
  end

  def test_checkout_cannot_be_before_checkin
    t_now = Time.now
    attendance = @stop.stop_attendances.new(
      check_in_at: t_now,
      check_out_at: t_now - 600, # 10 min antes
      status: StopAttendance::STATUS_VISITED
    )
    refute attendance.valid?
    assert_includes attendance.errors[:check_out_at], 'não pode ser anterior ao check-in'
  end

  def test_automatically_calculates_visit_duration_seconds_before_save
    t_in = Time.now - 1800 # 30 min atrás
    t_out = Time.now

    attendance = @stop.stop_attendances.create!(
      check_in_at: t_in,
      check_out_at: t_out,
      status: StopAttendance::STATUS_VISITED,
      feedback: 'Visita concluída com sucesso'
    )

    assert_equal 1800, attendance.visit_duration_seconds
  end

  def test_association_with_route_through_stop
    attendance = @stop.stop_attendances.create!(
      check_in_at: Time.now,
      status: StopAttendance::STATUS_IN_PROGRESS
    )
    assert_equal @route.id, attendance.route.id
  end
end

