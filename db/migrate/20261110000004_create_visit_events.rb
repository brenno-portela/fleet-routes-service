# frozen_string_literal: true

class CreateVisitEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :visit_events do |t|
      t.references :route, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :route_stop, foreign_key: { on_delete: :nullify }, index: true
      t.string :event_type, null: false, index: true
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.datetime :recorded_at, null: false, index: true
      t.text :metadata

      t.timestamps
    end

    add_index :visit_events, %i[route_id event_type recorded_at]
  end
end

