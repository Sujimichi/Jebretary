# encoding: UTF-8
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

ActiveRecord::Schema.define(:version => 20140814094457) do

  create_table "campaigns", :force => true do |t|
    t.integer  "instance_id"
    t.string   "name"
    t.string   "persistence_checksum"
    t.datetime "created_at",           :null => false
    t.datetime "updated_at",           :null => false
    t.text     "commit_messages"
    t.string   "sort_options"
  end

  create_table "crafts", :force => true do |t|
    t.string   "name"
    t.string   "craft_type"
    t.integer  "part_count"
    t.boolean  "deleted",         :default => false
    t.integer  "campaign_id"
    t.integer  "history_count"
    t.string   "last_commit"
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.text     "commit_messages"
    t.text     "part_data"
    t.string   "sync"
  end

  create_table "instances", :force => true do |t|
    t.string   "full_path"
    t.datetime "created_at",                              :null => false
    t.datetime "updated_at",                              :null => false
    t.string   "part_db_checksum"
    t.boolean  "part_update_required", :default => false
    t.boolean  "use_x64_exe",          :default => false
  end

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :null => false
    t.text     "data"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "subassemblies", :force => true do |t|
    t.string   "name"
    t.integer  "campaign_id"
    t.integer  "history_count"
    t.boolean  "deleted",       :default => false
    t.string   "last_commit"
    t.datetime "created_at",                       :null => false
    t.datetime "updated_at",                       :null => false
    t.string   "sync"
  end

  create_table "tasks", :force => true do |t|
    t.string   "action"
    t.boolean  "failed",     :default => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
  end

end
