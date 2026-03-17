class CreateScrapingUrls < ActiveRecord::Migration[7.1]
  def change
    create_table :scraping_urls do |t|
      t.string :url, null: false
      t.integer :url_type, default: 0, null: false
      t.string :label
      t.boolean :active, default: true, null: false
      t.datetime :last_scraped_at

      t.timestamps
    end
    add_index :scraping_urls, :url, unique: true
    add_index :scraping_urls, :active
  end
end
