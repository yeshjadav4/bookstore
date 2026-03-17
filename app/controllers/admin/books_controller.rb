module Admin
  class BooksController < ApplicationController
    include Pagy::Backend
    layout "admin"

    def index
      per_page = params[:per_page].presence_in(%w[10 20 50 100]) || "10"
      @pagy, @books = pagy(Book.listed.order(created_at: :desc), items: per_page.to_i)
    end

    def new
      @book = Book.new
    end

    def create
      @book = Book.new(book_params)
      if @book.save
        redirect_to admin_books_path, notice: "Book created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @book = Book.find(params[:id])
    end

    def update
      @book = Book.find(params[:id])
      if @book.update(book_params)
        redirect_to admin_books_path, notice: "Book updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      Book.find(params[:id]).destroy
      redirect_to admin_books_path, notice: "Book deleted."
    end

    private

    def book_params
      params.require(:book).permit(
        :title,
        :author,
        :price,
        :isbn,
        :publisher,
        :edition,
        :pages,
        :category,
        :rating,
        :reviews_count,
        :description,
        :source_url,
        :image_url,
        :scraped_at
      )
    end
  end
end

