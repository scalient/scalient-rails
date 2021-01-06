# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 0) do

  create_table "organizations", force: :cascade do |t|
    t.string "name"
  end

  create_table "references", force: :cascade do |t|
    t.string "referrer_type"
    t.integer "referrer_id"
    t.string "referent_type"
    t.integer "referent_id"
    t.index ["referent_type", "referent_id"], name: "index_references_on_referent"
    t.index ["referrer_type", "referrer_id"], name: "index_references_on_referrer"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "users_organizations", force: :cascade do |t|
    t.integer "user_id"
    t.integer "organization_id"
    t.boolean "admin", null: false
    t.boolean "home", null: false
    t.index ["organization_id"], name: "index_users_organizations_on_organization_id"
    t.index ["user_id"], name: "index_users_organizations_on_user_id"
  end

  add_foreign_key "users_organizations", "organizations", on_delete: :cascade
  add_foreign_key "users_organizations", "users", on_delete: :cascade
end
