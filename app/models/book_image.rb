class BookImage < ApplicationRecord
  belongs_to :book

  validates :image_url, presence: true
  validates :sequence, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :sequence, uniqueness: { scope: :book_id }

  scope :ordered, -> { order(sequence: :asc) }
end

