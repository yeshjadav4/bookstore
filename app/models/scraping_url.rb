class ScrapingUrl < ApplicationRecord
  enum url_type: { product: 0, listing: 1 }

  has_many :scrape_logs, dependent: :destroy

  validates :url, presence: true, uniqueness: true
  validates :url_type, presence: true

  scope :active, -> { where(active: true) }

  def display_name
    label.presence || url.truncate(60)
  end
end
