class Book < ApplicationRecord
  validates :title, presence: true
  validates :isbn, uniqueness: true, allow_blank: true

  scope :listed, -> { where.not(price: [nil, 0]) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :search_by_title, ->(q) { where("title ILIKE ?", "%#{q}%") if q.present? }
  scope :price_between, ->(min, max) {
    rel = all
    rel = rel.where("price >= ?", min) if min.present?
    rel = rel.where("price <= ?", max) if max.present?
    rel
  }

  CSV_HEADERS = %w[
    id title author price isbn publisher edition pages
    category rating reviews_count description source_url image_url scraped_at
  ].freeze

  def csv_row
    CSV_HEADERS.map { |attr| send(attr) }
  end

  def display_author
    names = author.to_s.split(/[|,\/;&]+/).map(&:strip).reject(&:blank?)
    names = [author.to_s] if names.empty?

    names = names.map do |name|
      name == "Taxmann's Editorial Board" ? "Taxman" : name
    end

    names.uniq.join(" | ")
  end

  def discounted_price
    return price unless discount_percent.present? && price.present?

    (price * (100 - discount_percent.to_f) / 100.0).round(2)
  end

  def discount?
    discounted_price.present? && price.present? && discounted_price < price
  end

  def self.upsert_from_scraped(data)
    if data[:isbn].present?
      book = find_or_initialize_by(isbn: data[:isbn])
    elsif data[:source_url].present?
      book = find_or_initialize_by(source_url: data[:source_url])
    else
      book = find_or_initialize_by(title: data[:title], author: data[:author])
    end
    book.assign_attributes(data.merge(scraped_at: Time.current))
    book.save!
    book
  end
end
