module Admin
  class ScrapeLogsController < ApplicationController
    layout "admin"

    def index
      @scrape_logs = ScrapeLog.includes(:scraping_url).recent.limit(100)
    end
  end
end
