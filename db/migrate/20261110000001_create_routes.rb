# frozen_string_literal: true

class CreateRoutes < ActiveRecord::Migration[7.1]
  def change
    create_table :routes do |t|
      t.string :name, null: false
      t.string :seller_uid, null: false, index: true
      t.string :seller_name
      t.string :seller_email
      t.string :status, null: false, default: 'assigned', index: true
      t.date :due_date, index: true
      t.integer :target_completion_percent, default: 90, null: false
      t.integer :target_completed_stops
      t.decimal :origin_latitude, precision: 10, scale: 7
      t.decimal :origin_longitude, precision: 10, scale: 7
      t.float :estimated_distance_meters
      t.integer :estimated_duration_seconds
      t.string :assignment_type, default: 'shared'
      t.text :assignment_notes
      t.text :not_completed_reason
      t.string :state, limit: 2, index: true
      t.string :created_by_uid
      t.string :created_by_name
      t.string :last_edited_by_uid
      t.string :last_edited_by_name

      t.timestamps
    end

    add_index :routes, %i[status created_at]
    add_index :routes, %i[seller_uid created_at]
  end
end

