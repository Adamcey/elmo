# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110624133714) do

  create_table "google_geolocations", :force => true do |t|
    t.string   "full_name"
    t.text     "json"
    t.integer  "place_type_id"
    t.decimal  "latitude",       :precision => 20, :scale => 15
    t.decimal  "longitude",      :precision => 20, :scale => 15
    t.string   "formatted_addr"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "languages", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "is_active"
  end

  create_table "permissions", :force => true do |t|
    t.string   "controller"
    t.string   "action"
    t.integer  "role_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "place_lookups", :force => true do |t|
    t.string   "query"
    t.string   "sugg_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "place_sugg_sets", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "place_suggs", :force => true do |t|
    t.integer  "place_lookup_id"
    t.integer  "place_id"
    t.integer  "google_geolocation_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "place_types", :force => true do |t|
    t.string   "name"
    t.integer  "level"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "places", :force => true do |t|
    t.string   "long_name"
    t.string   "short_name"
    t.string   "full_name"
    t.integer  "place_type_id"
    t.integer  "container_id"
    t.decimal  "latitude",      :precision => 20, :scale => 15
    t.decimal  "longitude",     :precision => 20, :scale => 15
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "roles", :force => true do |t|
    t.string   "name"
    t.integer  "level"
    t.boolean  "location_required"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "searches", :force => true do |t|
    t.string   "query"
    t.string   "class_name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "login"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "email"
    t.integer  "language_id"
    t.integer  "role_id"
    t.integer  "location_id"
    t.string   "phone"
    t.boolean  "is_mobile_phone"
    t.boolean  "is_active"
    t.string   "password_salt"
    t.string   "crypted_password"
    t.string   "single_access_token"
    t.string   "perishable_token"
    t.string   "persistence_token"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["login"], :name => "index_users_on_login", :unique => true

end
