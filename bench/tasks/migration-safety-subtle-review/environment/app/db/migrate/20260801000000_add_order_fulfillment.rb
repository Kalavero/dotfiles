class AddOrderFulfillment < ActiveRecord::Migration[7.1]
  def up
    add_column :orders, :reference, :string, default: -> { "gen_random_uuid()" }
    add_column :orders, :priority, :integer, default: 0
    add_column :orders, :fulfillment_notes, :text

    add_check_constraint :orders, "total > 0", name: "orders_total_positive"

    add_index :orders, [:account_id, :status],
              where: "status = 'pending'",
              name: "idx_orders_account_pending"

    add_foreign_key :orders, :accounts

    rename_column :orders, :total, :total_amount

    Order.reset_column_information
    Order.where(reference: nil).find_each do |order|
      order.update_columns(reference: SecureRandom.uuid)
    end
  end

  def down
    remove_column :orders, :reference
    remove_column :orders, :priority
    remove_column :orders, :fulfillment_notes
    remove_check_constraint :orders, name: "orders_total_positive"
    remove_index :orders, name: "idx_orders_account_pending"
    remove_foreign_key :orders, :accounts
    rename_column :orders, :total_amount, :total
  end
end
