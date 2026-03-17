class CreateBooks < ActiveRecord::Migration[7.1]
  def change
    create_table :books do |t|
      t.string :title
      t.string :author
      t.decimal :price, precision: 10, scale: 2
      t.text :image_url
      t.text :description
      t.string :isbn
      t.string :publisher
      t.string :edition
      t.integer :pages
      t.string :category
      t.integer :reviews_count, default: 0
      t.decimal :rating, precision: 3, scale: 1
      t.text :source_url
      t.datetime :scraped_at

      t.timestamps
    end
    add_index :books, :isbn, unique: true
    add_index :books, :category
    add_index :books, :title
  end
end
