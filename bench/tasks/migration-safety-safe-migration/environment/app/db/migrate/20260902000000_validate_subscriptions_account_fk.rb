class ValidateSubscriptionsAccountFk < ActiveRecord::Migration[7.1]
  def up
    validate_foreign_key :subscriptions, :accounts
  end

  def down
    # Validation changes no schema; nothing to undo.
  end
end
