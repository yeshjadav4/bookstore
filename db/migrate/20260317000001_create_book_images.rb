class CreateBookImages < ActiveRecord::Migration[7.1]
  def up
    create_table :book_images do |t|
      t.references :book, null: false, foreign_key: true
      t.text :image_url, null: false
      t.integer :sequence, null: false
      t.timestamps
    end

    add_index :book_images, %i[book_id sequence], unique: true

    backfill_from_legacy_columns
  end

  def down
    drop_table :book_images
  end

  private

  def backfill_from_legacy_columns
    say_with_time "Backfilling book_images from books.image_url / books.extra_image_urls" do
      book_klass = Class.new(ActiveRecord::Base) { self.table_name = "books" }
      book_image_klass = Class.new(ActiveRecord::Base) { self.table_name = "book_images" }

      book_klass.reset_column_information

      book_klass.find_each do |book|
        urls = []
        urls << book.image_url if book.image_url.present?
        urls.concat(parse_legacy_extra_images(book.extra_image_urls))
        urls = urls.compact.map(&:to_s).map(&:strip).reject(&:blank?).uniq
        next if urls.empty?

        urls.each_with_index do |url, idx|
          book_image_klass.create!(book_id: book.id, image_url: url, sequence: idx + 1)
        end
      rescue ActiveRecord::RecordNotUnique
        # idempotency for partial runs
        next
      end
    end
  end

  def parse_legacy_extra_images(value)
    return [] if value.blank?
    return value if value.is_a?(Array)

    str = value.to_s.strip
    if str.start_with?("[")
      begin
        parsed = JSON.parse(str)
        return parsed if parsed.is_a?(Array)
      rescue JSON::ParserError
        # fallthrough
      end
    end

    if str.start_with?("---")
      begin
        loaded = YAML.safe_load(str, permitted_classes: [String], aliases: false)
        return loaded if loaded.is_a?(Array)
      rescue StandardError
        # fallthrough
      end
    end

    str.split(/[\s,|]+/).reject(&:blank?)
  end
end

