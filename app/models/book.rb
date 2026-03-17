class Book < ApplicationRecord
  has_many :book_images, dependent: :destroy

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
    data = data.dup
    data[:title] = sanitize_scraped_title(title: data[:title], source_url: data[:source_url])

    if data[:isbn].present?
      book = find_or_initialize_by(isbn: data[:isbn])
    elsif data[:source_url].present?
      book = find_or_initialize_by(source_url: data[:source_url])
    else
      book = find_or_initialize_by(title: data[:title], author: data[:author])
    end

    image_urls = normalize_image_urls(data)
    persisted_attrs = data.except(:image_urls)
    persisted_attrs[:image_url] = image_urls.first if image_urls.any?
    persisted_attrs[:extra_image_urls] = nil

    transaction do
      book.assign_attributes(persisted_attrs.merge(scraped_at: Time.current))
      book.save!
      book.sync_book_images!(image_urls)
    end

    book
  end

  def self.sanitize_scraped_title(title:, source_url:)
    t = title.to_s.strip
    normalized = t.downcase.gsub(/\s+/, " ").gsub(/[[:punct:]]+\z/, "")

    invalid = normalized.blank? ||
              normalized.match?(/\A(buying options|buy now|add to cart|view content|view sample chapter|quantity|in stock)\b/i) ||
              normalized.match?(/\A(print book|virtual book)\b/i)

    return t unless invalid

    slug = source_url.to_s.split("/").last.to_s
    slug.sub(/\A\d+-/, "").tr("-", " ").gsub(/\b\w/, &:upcase).presence || t
  end

  def sync_book_images!(image_urls)
    urls = Array(image_urls).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    return if urls.empty?

    desired = urls.each_with_index.map { |url, idx| [idx + 1, url] }.to_h

    book_images.where.not(sequence: desired.keys).delete_all

    desired.each do |sequence, url|
      book_images.find_or_initialize_by(sequence: sequence).tap do |img|
        img.image_url = url
        img.save! if img.changed?
      end
    end
  end

  def all_image_urls
    urls = book_images.ordered.pluck(:image_url)
    return urls if urls.any?

    [image_url.to_s.presence, *self.class.parse_legacy_extra_images(extra_image_urls)].compact
  end

  def self.normalize_image_urls(data)
    urls = Array(data[:image_urls]).presence
    urls ||= [data[:image_url], *Array(data[:extra_image_urls])]
    urls.compact.map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def self.parse_legacy_extra_images(value)
    return [] if value.blank?
    return value if value.is_a?(Array)

    str = value.to_s.strip

    if str.start_with?("[")
      begin
        return JSON.parse(str)
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
