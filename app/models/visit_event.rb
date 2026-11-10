# frozen_string_literal: true

class VisitEvent < ApplicationRecord
  EVENT_LOCATION_SAMPLE    = 'location_sample'
  EVENT_CHECK_IN           = 'check_in'
  EVENT_CHECK_OUT          = 'check_out'
  EVENT_FEEDBACK_SUBMITTED = 'feedback_submitted'
  EVENT_ROUTE_STARTED      = 'route_started'
  EVENT_ROUTE_FINISHED     = 'route_finished'

  EVENT_TYPES = [
    EVENT_LOCATION_SAMPLE,
    EVENT_CHECK_IN,
    EVENT_CHECK_OUT,
    EVENT_FEEDBACK_SUBMITTED,
    EVENT_ROUTE_STARTED,
    EVENT_ROUTE_FINISHED
  ].freeze

  belongs_to :route, inverse_of: :visit_events
  belongs_to :route_stop, optional: true, inverse_of: :visit_events

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :latitude, presence: true
  validates :longitude, presence: true
  validates :recorded_at, presence: true

  validate :coordinates_must_be_valid

  scope :location_samples, -> { where(event_type: EVENT_LOCATION_SAMPLE) }
  scope :feedback_events, -> { where(event_type: EVENT_FEEDBACK_SUBMITTED) }
  scope :chronological, -> { order(recorded_at: :asc) }

  private

  def coordinates_must_be_valid
    unless Routes::HaversineDistance.valid_coordinates?(latitude, longitude)
      errors.add(:coordinates, 'devem ser uma latitude e longitude terrestres válidas e não nulas')
    end
  end
end

