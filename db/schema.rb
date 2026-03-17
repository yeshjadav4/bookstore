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

ActiveRecord::Schema[7.1].define(version: 2026_03_17_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "book_images", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.text "image_url", null: false
    t.integer "sequence", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "sequence"], name: "index_book_images_on_book_id_and_sequence", unique: true
    t.index ["book_id"], name: "index_book_images_on_book_id"
  end

  create_table "books", force: :cascade do |t|
    t.string "title"
    t.string "author"
    t.decimal "price", precision: 10, scale: 2
    t.text "image_url"
    t.text "description"
    t.string "isbn"
    t.string "publisher"
    t.string "edition"
    t.integer "pages"
    t.string "category"
    t.integer "reviews_count", default: 0
    t.decimal "rating", precision: 3, scale: 1
    t.text "source_url"
    t.datetime "scraped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "discount_percent", precision: 5, scale: 2
    t.text "extra_image_urls"
    t.index ["category"], name: "index_books_on_category"
    t.index ["isbn"], name: "index_books_on_isbn", unique: true
    t.index ["title"], name: "index_books_on_title"
  end

  create_table "scrape_logs", force: :cascade do |t|
    t.bigint "scraping_url_id", null: false
    t.integer "status"
    t.integer "books_found"
    t.text "error_message"
    t.float "duration_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scraping_url_id"], name: "index_scrape_logs_on_scraping_url_id"
  end

  create_table "scraping_urls", force: :cascade do |t|
    t.string "url", null: false
    t.integer "url_type", default: 0, null: false
    t.string "label"
    t.boolean "active", default: true, null: false
    t.datetime "last_scraped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_scraping_urls_on_active"
    t.index ["url"], name: "index_scraping_urls_on_url", unique: true
  end

  add_foreign_key "book_images", "books"
  add_foreign_key "scrape_logs", "scraping_urls"
end
