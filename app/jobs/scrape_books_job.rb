class ScrapeBooksJob < ApplicationJob
  queue_as :scraping

  def perform(scraping_url_id = nil)
    urls = if scraping_url_id
             ScrapingUrl.where(id: scraping_url_id)
           else
             ScrapingUrl.active
           end

    urls.find_each do |scraping_url|
      start_time = Time.current
      scraper = TaxmannScraper.new(scraping_url.url)

      begin
        if scraping_url.product?
          data = scraper.scrape_product_page
          Book.upsert_from_scraped(data)
          books_found = 1
        else
          results = scraper.scrape_listing_page
          books_found = 0
          results.each do |data|
            Book.upsert_from_scraped(data)
            books_found += 1
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.warn("[ScrapeBooksJob] Skipping invalid book (#{data[:source_url]}): #{e.message}")
          end
        end

        scraping_url.update!(last_scraped_at: Time.current)

        ScrapeLog.create!(
          scraping_url: scraping_url,
          status: :success,
          books_found: books_found,
          duration_seconds: Time.current - start_time
        )
      rescue => e
        ScrapeLog.create!(
          scraping_url: scraping_url,
          status: :failure,
          books_found: 0,
          error_message: "#{e.class}: #{e.message}",
          duration_seconds: Time.current - start_time
        )
        Rails.logger.error("[ScrapeBooksJob] Error scraping #{scraping_url.url}: #{e.message}")
      end
    end
  end
end
