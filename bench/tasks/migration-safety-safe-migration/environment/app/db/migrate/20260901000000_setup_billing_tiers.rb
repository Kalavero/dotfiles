class SetupBillingTiers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    add_column :subscriptions, :billing_interval, :string
    add_column :subscriptions, :plan_code, :string, default: "free", null: false
    add_column :subscriptions, :trial_ends_at, :datetime

    add_index :subscriptions, [:account_id, :plan_code],
              algorithm: :concurrently,
              name: "idx_subscriptions_account_plan"

    add_foreign_key :subscriptions, :accounts, validate: false
  end

  def down
    remove_foreign_key :subscriptions, :accounts
    remove_index :subscriptions, name: "idx_subscriptions_account_plan"
    remove_column :subscriptions, :trial_ends_at
    remove_column :subscriptions, :plan_code
    remove_column :subscriptions, :billing_interval
  end
end
