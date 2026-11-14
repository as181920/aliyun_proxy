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

ActiveRecord::Schema[8.1].define(version: 2024_01_03_103328) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "aliyun_pnvs_verify_schemes", force: :cascade do |t|
    t.string "scheme_name"
    t.string "app_name"
    t.string "os_type"
    t.string "origin"
    t.string "url"
    t.integer "state"
    t.string "scheme_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "aliyun_sms_sign_holder_maps", force: :cascade do |t|
    t.bigint "sign_id"
    t.string "holder_type"
    t.bigint "holder_id"
    t.datetime "created_at"
    t.index ["holder_type", "holder_id"], name: "index_aliyun_sms_sign_holder_maps_on_holder"
    t.index ["sign_id", "holder_id", "holder_type"], name: "index_alisms_sign_holder_maps_on_sign_and_holder", unique: true
    t.index ["sign_id"], name: "index_aliyun_sms_sign_holder_maps_on_sign_id"
  end

  create_table "aliyun_sms_signs", force: :cascade do |t|
    t.string "name"
    t.integer "state"
    t.integer "source_type"
    t.text "remark"
    t.jsonb "file_list"
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_aliyun_sms_signs_on_name", unique: true
  end

  create_table "aliyun_sms_template_holder_maps", force: :cascade do |t|
    t.bigint "template_id"
    t.string "holder_type"
    t.bigint "holder_id"
    t.datetime "created_at"
    t.index ["holder_type", "holder_id"], name: "index_aliyun_sms_template_holder_maps_on_holder"
    t.index ["template_id", "holder_id", "holder_type"], name: "index_alisms_template_holder_maps_on_tmpl_and_holder", unique: true
    t.index ["template_id"], name: "index_aliyun_sms_template_holder_maps_on_template_id"
  end

  create_table "aliyun_sms_templates", force: :cascade do |t|
    t.string "name"
    t.integer "state"
    t.integer "message_type"
    t.text "content"
    t.string "content_digest"
    t.text "remark"
    t.text "reason"
    t.string "template_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_digest"], name: "index_aliyun_sms_templates_on_content_digest"
    t.index ["name"], name: "index_aliyun_sms_templates_on_name"
    t.index ["template_code"], name: "index_aliyun_sms_templates_on_template_code", unique: true
  end
end
