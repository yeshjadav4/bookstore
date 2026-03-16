require "csv"

class BooksController < ApplicationController
  include Pagy::Backend

  def index
    books = Book.listed
    books = books.search_by_title(params[:q]) if params[:q].present?
    books = books.by_category(params[:category]) if params[:category].present?
    books = books.price_between(params[:min_price], params[:max_price])

    books = case params[:sort]
            when "price_asc" then books.order(price: :asc)
            when "price_desc" then books.order(price: :desc)
            when "title" then books.order(title: :asc)
            when "newest" then books.order(scraped_at: :desc)
            else books.order(created_at: :desc)
            end

    @categories = Book.distinct.pluck(:category).compact.sort
    @pagy, @books = pagy(books, items: 12)
  end

  def show
    @book = Book.find(params[:id])
  end

  def export
    books = Book.listed
    csv_data = CSV.generate(headers: true) do |csv|
      csv << Book::CSV_HEADERS
      books.each { |b| csv << b.csv_row }
    end
    send_data csv_data,
              filename: "taxmann_books_#{Date.today}.csv",
              type: "text/csv",
              disposition: "attachment"
  end
end
