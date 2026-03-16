require "ferrum"
require "nokogiri"
require "json"

class TaxmannScraper
  RENDER_WAIT = 5
  MAX_WAIT = 15
  CHROME_PATH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome".freeze
  BASE_URL = "https://www.taxmann.com".freeze

  def initialize(url)
    @url = url
    @browser = nil
  end

  def scrape_product_page
    boot_browser
    navigate_and_wait(@url)

    extract_product_from_page
  rescue => e
    Rails.logger.error("[TaxmannScraper] Product scrape failed for #{@url}: #{e.message}")
    raise
  ensure
    shutdown_browser
  end

  def scrape_listing_page
    boot_browser
    navigate_and_wait(@url)

    product_links = extract_product_links
    Rails.logger.info("[TaxmannScraper] Found #{product_links.size} product links on #{@url}")

    books = []
    product_links.each do |link|
      navigate_and_wait(link)
      data = extract_product_from_page
      data[:source_url] = link

      if data[:title].blank?
        data[:title] = title_from_url(link)
        Rails.logger.warn("[TaxmannScraper] Used URL-derived title for #{link}: #{data[:title]}")
      end

      books << data if data[:title].present?
    rescue => e
      Rails.logger.error("[TaxmannScraper] Failed to scrape #{link}: #{e.message}")
      next
    end
    books
  rescue => e
    Rails.logger.error("[TaxmannScraper] Listing scrape failed for #{@url}: #{e.message}")
    raise
  ensure
    shutdown_browser
  end

  private

  def navigate_and_wait(url)
    @browser.goto(url)
    wait_for_content
  end

  def wait_for_content
    elapsed = 0
    loop do
      sleep(1)
      elapsed += 1

      has_content = @browser.evaluate(<<~JS)
        !!(
          document.querySelector('script[type="application/ld+json"]') ||
          document.querySelector('h1') ||
          document.querySelector('[class*="productName"]') ||
          document.querySelector('[class*="product-name"]') ||
          document.querySelector('[class*="ProductName"]') ||
          document.querySelector('[class*="bookTitle"]') ||
          document.querySelector('[class*="book-title"]') ||
          document.body.innerText.length > 500
        )
      JS

      break if has_content || elapsed >= MAX_WAIT
    end

    sleep(RENDER_WAIT) if elapsed >= MAX_WAIT
  end

  def boot_browser
    options = {
      headless: "new",
      timeout: 60,
      process_timeout: 30,
      browser_options: { "no-sandbox" => nil },
      window_size: [1440, 900]
    }
    options[:browser_path] = CHROME_PATH if File.exist?(CHROME_PATH)
    @browser = Ferrum::Browser.new(**options)
  end

  def shutdown_browser
    @browser&.quit
  rescue StandardError
    nil
  end

  def extract_product_from_page
    doc = Nokogiri::HTML(@browser.body)
    json_ld_data = extract_json_ld(doc)
    page_text = @browser.evaluate("document.body.innerText") rescue ""

    product_ld = json_ld_data.find { |d| d["@type"] == "Product" } || {}
    book_ld = json_ld_data.find { |d| d["@type"] == "Book" } || {}

    title = product_ld.dig("name") ||
            book_ld.dig("name") ||
            extract_title_from_dom(doc) ||
            extract_title_from_text(page_text)

    author = extract_author_from_ld(product_ld, book_ld) ||
             extract_author_from_dom(doc) ||
             extract_author_from_text(page_text)

    price = extract_price_from_ld(product_ld) ||
            extract_price_from_text(page_text)

    image_urls = Array(product_ld["image"] || book_ld["image"]).presence || extract_images_from_dom(doc)
    primary_image = image_urls.first
    extra_images = image_urls.drop(1)

    description = product_ld.dig("description") ||
                  book_ld.dig("description") ||
                  extract_description_from_dom(doc)

    isbn = book_ld.dig("isbn") ||
           extract_property(product_ld, "ISBN") ||
           extract_isbn_from_text(page_text)

    publisher = extract_property(product_ld, "Publisher") ||
                book_ld.dig("publisher", "name") ||
                extract_field_from_text(page_text, "Publisher")

    edition = extract_property(product_ld, "Edition") ||
              extract_field_from_text(page_text, "Edition")

    pages = extract_pages_from_ld(product_ld) ||
            extract_pages_from_text(page_text)

    if title.blank?
      Rails.logger.warn("[TaxmannScraper] No title found. JSON-LD types: #{json_ld_data.map { |d| d['@type'] }}. " \
                        "Body length: #{doc.text.length}. Text length: #{page_text.length}")
    end

    {
      title: title,
      author: author,
      price: price,
      image_url: primary_image,
      extra_image_urls: extra_images,
      description: description.to_s.strip.presence,
      isbn: isbn,
      publisher: publisher,
      edition: edition,
      pages: pages,
      category: nil,
      reviews_count: 0,
      rating: nil,
      source_url: @url
    }
  end

  # --- JSON-LD extraction ---

  def extract_json_ld(doc)
    doc.css('script[type="application/ld+json"]').filter_map do |script|
      parsed = JSON.parse(script.text.strip)
      parsed.is_a?(Array) ? parsed : [parsed]
    rescue JSON::ParserError
      nil
    end.flatten
  end

  def extract_author_from_ld(product, book)
    from_properties = extract_property(product, "Author")
    return from_properties if from_properties

    author_data = book.dig("author")
    return unless author_data

    author_data.is_a?(Hash) ? author_data["name"] : author_data.to_s
  end

  def extract_price_from_ld(product)
    offers = product.dig("offers")
    return unless offers

    case offers
    when Hash
      offers.dig("price")&.to_f
    when Array
      offers.first&.dig("price")&.to_f
    end
  end

  def extract_property(product, name)
    props = Array(product.dig("additionalProperty"))
    match = props.find { |p| p["name"] == name }
    match&.dig("value")
  end

  def extract_pages_from_ld(product)
    value = extract_property(product, "Number of Pages")
    value&.to_i if value.present?
  end

  # --- DOM-based extraction (CSS selectors) ---

  def extract_title_from_dom(doc)
    selectors = [
      "h1",
      "[class*='productName']", "[class*='product-name']", "[class*='ProductName']",
      "[class*='bookTitle']", "[class*='book-title']", "[class*='BookTitle']",
      "h2", "h3"
    ]
    selectors.each do |sel|
      doc.css(sel).each do |node|
        text = node.text.strip
        return text if text.present? && text.length > 3 && text.length < 500
      end
    end
    nil
  end

  def extract_author_from_dom(doc)
    selectors = [
      "[class*='author']", "[class*='Author']",
      "[class*='writer']", "[class*='Writer']"
    ]
    selectors.each do |sel|
      node = doc.at_css(sel)
      if node && node.text.strip.present?
        return node.text.strip.sub(/\ABy\s+/i, "").strip
      end
    end
    nil
  end

  def extract_images_from_dom(doc)
    selectors = [
      "img[src*='BookshopFiles']", "img[src*='Bookimg']", "img[src*='bookimg']",
      "img[src*='cdn.taxmann.com']",
      ".product-image img", "[class*='productImage'] img",
      "[class*='product-img'] img", "[class*='bookImage'] img"
    ]
    urls = []
    selectors.each do |sel|
      doc.css(sel).each do |img|
        src = img["src"] || img["data-src"]
        next unless src.present?
        full = src.start_with?("http") ? src : "#{BASE_URL}#{src}"
        urls << full
      end
    end
    urls.uniq
  end

  def extract_description_from_dom(doc)
    selectors = [
      "[class*='description']", "[class*='Description']",
      "[class*='about']", ".product-description"
    ]
    selectors.each do |sel|
      node = doc.at_css(sel)
      return node.text.strip if node && node.text.strip.length > 20
    end
    nil
  end

  # --- Plain text extraction (from page innerText) ---

  def extract_title_from_text(text)
    lines = text.split("\n").map(&:strip).reject(&:blank?)
    lines.each do |line|
      next if line.length < 5 || line.length > 300
      next if line.match?(/sign in|log in|cart|menu|home|bookstore|taxmann/i) && line.length < 30
      return line
    end
    nil
  end

  def extract_author_from_text(text)
    match = text.match(/(?:By|Author)[:\s]+([^\n]{3,100})/i)
    match ? match[1].strip : nil
  end

  def extract_price_from_text(text)
    match = text.match(/₹\s*([\d,]+)/)
    match ? match[1].gsub(",", "").to_f : nil
  end

  def extract_isbn_from_text(text)
    match = text.match(/ISBN[:\s]*([\d\-X]{10,17})/i)
    match ? match[1].gsub("-", "") : nil
  end

  def extract_field_from_text(text, label)
    match = text.match(/#{Regexp.escape(label)}[:\s]+([^\n]{2,100})/i)
    match ? match[1].strip : nil
  end

  def extract_pages_from_text(text)
    match = text.match(/(?:Pages?|No\.?\s*of\s*Pages)[:\s]*(\d+)/i)
    match ? match[1].to_i : nil
  end

  # --- URL-based fallback ---

  def title_from_url(url)
    slug = url.split("/").last.to_s
    slug.sub(/\A\d+-/, "")
        .tr("-", " ")
        .gsub(/\b\w/, &:upcase)
        .presence
  end

  # --- Product links extraction ---

  def extract_product_links
    doc = Nokogiri::HTML(@browser.body)

    links = doc.css("a[href*='/bookstore/product/']").filter_map { |a| a["href"] }.uniq
    links.map! { |l| l.start_with?("http") ? l : "#{BASE_URL}#{l}" }

    if links.empty?
      json_ld_data = extract_json_ld(doc)
      json_ld_data.each do |data|
        url = data.dig("offers", "url") || Array(data.dig("offers")).first&.dig("url")
        links << url if url&.include?("/bookstore/product/")
      end
      links.uniq!
    end

    Rails.logger.info("[TaxmannScraper] Extracted #{links.size} product links")
    links
  end
end
