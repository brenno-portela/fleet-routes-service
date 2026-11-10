# frozen_string_literal: true

class CreateStopAttendances < ActiveRecord::Migration[7.1]
  def change
    create_table :stop_attendances do |t|
      t.references :route_stop, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.string :status, null: false, default: 'pending', index: true
      t.datetime :check_in_at, null: false, index: true
      t.datetime :check_out_at
      t.text :feedback
      t.text :not_visited_reason
      t.text :commercial_outcome
      t.text :next_action
      t.date :next_action_due_date
      t.decimal :check_in_latitude, precision: 10, scale: 7
      t.decimal :check_in_longitude, precision: 10, scale: 7
      t.decimal :check_out_latitude, precision: 10, scale: 7
      t.decimal :check_out_longitude, precision: 10, scale: 7
      t.float :check_in_distance_meters
      t.float :check_out_distance_meters
      t.integer :visit_duration_seconds

      t.timestamps
    end

    add_index :stop_attendances, %i[route_stop_id check_in_at]
  end
end

