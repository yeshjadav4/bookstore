module Admin
  class BookImagesController < ApplicationController
    layout "admin"

    def index
      @book = Book.find(params[:book_id])
      @book_images = @book.book_images.order(sequence: :asc)
    end

    def destroy
      book = Book.find(params[:book_id])
      book_image = book.book_images.find(params[:id])
      book_image.destroy!

      redirect_back fallback_location: edit_admin_book_path(book), notice: "Image deleted."
    end
  end
end

