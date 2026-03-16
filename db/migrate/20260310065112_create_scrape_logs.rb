class CreateScrapeLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :scrape_logs do |t|
      t.references :scraping_url, null: false, foreign_key: true
      t.integer :status
      t.integer :books_found
      t.text :error_message
      t.float :duration_seconds

      t.timestamps
    end
  end
end
