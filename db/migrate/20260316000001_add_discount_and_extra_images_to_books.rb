class AddDiscountAndExtraImagesToBooks < ActiveRecord::Migration[7.1]
  def change
    add_column :books, :discount_percent, :decimal, precision: 5, scale: 2
    add_column :books, :extra_image_urls, :text
  end
end

