# frozen_string_literal: true

require 'test_helper'

class VisitEventTest < Minitest::Test
  def setup
    @route = Route.create!(
      name: 'Rota Teste Eventos',
      seller_uid: 'seller_test',
      status: Route::STATUS_ASSIGNED
    )
  end

  def test_valid_location_sample_event
    event = @route.visit_events.new(
      event_type: VisitEvent::EVENT_LOCATION_SAMPLE,
      latitude: -23.55052,
      longitude: -46.633308,
      recorded_at: Time.now
    )
    assert event.valid?
    assert event.save
  end

  def test_requires_mandatory_attributes
    event = VisitEvent.new
    refute event.valid?
    assert_includes event.errors[:event_type], "can't be blank"
    assert_includes event.errors[:latitude], "can't be blank"
    assert_includes event.errors[:longitude], "can't be blank"
    assert_includes event.errors[:recorded_at], "can't be blank"
  end

  def test_event_type_inclusion_validation
    event = @route.visit_events.new(
      event_type: 'unrecognized_event',
      latitude: -23.55,
      longitude: -46.63,
      recorded_at: Time.now
    )
    refute event.valid?
    assert_includes event.errors[:event_type], 'is not included in the list'
  end

  def test_coordinates_must_be_geographically_valid
    invalid_event = @route.visit_events.new(
      event_type: VisitEvent::EVENT_LOCATION_SAMPLE,
      latitude: 0,
      longitude: 0,
      recorded_at: Time.now
    )
    refute invalid_event.valid?
    assert_includes invalid_event.errors[:coordinates], 'devem ser uma latitude e longitude terrestres válidas e não nulas'
  end

  def test_scopes_filter_correctly
    e1 = @route.visit_events.create!(
      event_type: VisitEvent::EVENT_LOCATION_SAMPLE,
      latitude: -23.55,
      longitude: -46.63,
      recorded_at: Time.now - 60
    )
    e2 = @route.visit_events.create!(
      event_type: VisitEvent::EVENT_FEEDBACK_SUBMITTED,
      latitude: -23.55,
      longitude: -46.63,
      recorded_at: Time.now
    )

    assert_includes VisitEvent.location_samples, e1
    refute_includes VisitEvent.location_samples, e2

    assert_includes VisitEvent.feedback_events, e2
    refute_includes VisitEvent.feedback_events, e1
  end
end

