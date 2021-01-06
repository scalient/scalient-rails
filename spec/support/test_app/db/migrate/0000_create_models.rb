# frozen_string_literal: true

class CreateModels < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
    end

    create_table :organizations do |t|
      t.string :name
    end

    create_table :users_organizations do |t|
      t.references :user, foreign_key: {on_delete: :cascade}
      t.references :organization, foreign_key: {on_delete: :cascade}

      t.boolean :admin, null: false
      t.boolean :home, null: false
    end

    create_table :references do |t|
      t.references :referrer, polymorphic: true
      t.references :referent, polymorphic: true
    end
  end
end
