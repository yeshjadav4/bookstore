module Admin
  class ScrapingUrlsController < ApplicationController
    layout "admin"

    def index
      @scraping_urls = ScrapingUrl.order(created_at: :desc)
    end

    def new
      @scraping_url = ScrapingUrl.new
    end

    def create
      @scraping_url = ScrapingUrl.new(scraping_url_params)
      if @scraping_url.save
        redirect_to admin_scraping_urls_path, notice: "URL added successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @scraping_url = ScrapingUrl.find(params[:id])
    end

    def update
      @scraping_url = ScrapingUrl.find(params[:id])
      if @scraping_url.update(scraping_url_params)
        redirect_to admin_scraping_urls_path, notice: "URL updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      ScrapingUrl.find(params[:id]).destroy
      redirect_to admin_scraping_urls_path, notice: "URL removed."
    end

    def toggle_active
      url = ScrapingUrl.find(params[:id])
      url.update!(active: !url.active)
      redirect_to admin_scraping_urls_path,
                  notice: "#{url.display_name} is now #{url.active? ? 'active' : 'inactive'}."
    end

    def scrape_now
      url = ScrapingUrl.find(params[:id])
      ScrapeBooksJob.perform_later(url.id)
      redirect_to admin_scraping_urls_path,
                  notice: "Scraping queued for #{url.display_name}."
    end

    def scrape_all
      ScrapeBooksJob.perform_later
      redirect_to admin_scraping_urls_path,
                  notice: "Full scrape queued for all active URLs."
    end

    private

    def scraping_url_params
      params.require(:scraping_url).permit(:url, :url_type, :label, :active)
    end
  end
end
