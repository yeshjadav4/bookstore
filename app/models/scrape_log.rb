class ScrapeLog < ApplicationRecord
  belongs_to :scraping_url

  enum status: { success: 0, failure: 1 }

  scope :recent, -> { order(created_at: :desc) }
end
