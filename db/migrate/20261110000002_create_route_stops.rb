# frozen_string_literal: true

class CreateRouteStops < ActiveRecord::Migration[7.1]
  def change
    create_table :route_stops do |t|
      t.references :route, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.string :customer_id, null: false, index: true
      t.string :customer_external_id
      t.string :minum_code
      t.bigint :odoo_lead_id
      t.string :odoo_external_id
      t.string :customer_name, null: false
      t.string :client_name
      t.string :opportunity
      t.string :cnpj_cpf, index: true
      t.text :address
      t.string :city
      t.string :state, limit: 2
      t.string :phone
      t.string :email
      t.string :segment
      t.string :pipeline_stage
      t.decimal :expected_revenue, precision: 12, scale: 2
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.integer :order, null: false
      t.string :status, null: false, default: 'assigned', index: true
      t.text :feedback
      t.text :not_visited_reason
      t.text :commercial_outcome
      t.text :next_action
      t.date :next_action_due_date
      t.datetime :check_in_at
      t.datetime :check_out_at
      t.float :check_in_distance_meters
      t.float :check_out_distance_meters
      t.integer :visit_duration_seconds

      t.timestamps
    end

    add_index :route_stops, %i[route_id order], unique: true
    add_index :route_stops, %i[route_id status]
  end
end

