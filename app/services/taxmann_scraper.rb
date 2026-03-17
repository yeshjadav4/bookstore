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

    title = nil unless valid_title?(title)
    title ||= title_from_url(@url)

    author = extract_author_from_ld(product_ld, book_ld) ||
             extract_author_from_dom(doc) ||
             extract_author_from_text(page_text)

    # Extract both original and discounted prices
    prices_data = extract_prices_and_discount(doc, page_text, product_ld)
    price = prices_data[:original_price]
    discount_percent = prices_data[:discount_percent]

    carousel_urls = extract_carousel_images_from_browser

    # Prefer only the product carousel thumbnails (requested behavior).
    image_urls =
      if carousel_urls.any?
        carousel_urls
      else
        []
          .concat(Array(product_ld["image"] || book_ld["image"]))
          .concat(extract_images_from_dom(doc))
          .concat(extract_images_from_browser)
      end
    image_urls = image_urls.map(&:to_s).map(&:strip).reject(&:blank?).uniq

    Rails.logger.info("[TaxmannScraper] Extracted #{image_urls.size} image(s) for #{@url}")

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
      discount_percent: discount_percent,
      image_url: image_urls.first,
      image_urls: image_urls,
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

    prices = case offers
             when Hash
               [offers.dig("price")&.to_f].compact
             when Array
               offers.filter_map { |o| o.dig("price")&.to_f }
             else
               []
             end

    return if prices.empty?

    prices.max
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
      "[itemprop='name']",
      "[class*='productName'] h1", "[class*='product-name'] h1", "[class*='ProductName'] h1",
      "[class*='bookTitle'] h1", "[class*='book-title'] h1", "[class*='BookTitle'] h1",
      "h1",
      "[class*='productName']", "[class*='product-name']", "[class*='ProductName']",
      "[class*='bookTitle']", "[class*='book-title']", "[class*='BookTitle']",
      "h2", "h3"
    ]
    selectors.each do |sel|
      doc.css(sel).each do |node|
        text = node.text.strip
        next unless valid_title?(text)
        return text
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
      "meta[property='og:image']",
      "meta[name='twitter:image']",
      "link[rel='image_src']",
      "img[src*='BookshopFiles']", "img[src*='Bookimg']", "img[src*='bookimg']",
      "img[src*='cdn.taxmann.com']",
      ".product-image img", "[class*='productImage'] img",
      "[class*='product-img'] img", "[class*='bookImage'] img",
      "[class*='thumb'] img", "[class*='thumbnail'] img",
      "[class*='carousel'] img", "[class*='slider'] img", "[class*='slick'] img",
      "img[data-zoom-image]", "img[data-large]", "img[data-large-image]", "img[data-src]", "img"
    ]

    urls = []

    selectors.each do |sel|
      doc.css(sel).each do |node|
        if node.name == "meta"
          urls << node["content"]
          next
        end

        if node.name == "link"
          urls << node["href"]
          next
        end

        urls.concat(image_urls_from_img(node))
      end
    end

    urls.filter_map { |u| normalize_image_url(u) }.uniq
  end

  def extract_images_from_browser
    Array(
      @browser.evaluate(<<~JS)
        (() => {
          const out = [];

          const add = (v) => {
            if (!v) return;
            if (Array.isArray(v)) { v.forEach(add); return; }
            out.push(String(v));
          };

          document.querySelectorAll('img').forEach((img) => {
            add(img.getAttribute('data-zoom-image'));
            add(img.getAttribute('data-large'));
            add(img.getAttribute('data-large-image'));
            add(img.getAttribute('data-src'));
            add(img.getAttribute('src'));

            const srcset = img.getAttribute('srcset') || '';
            srcset.split(',').forEach((entry) => {
              const url = entry.trim().split(/\s+/)[0];
              if (url) add(url);
            });
          });

          document.querySelectorAll('[style*="background-image"]').forEach((el) => {
            const style = el.getAttribute('style') || '';
            const m = style.match(/background-image\s*:\s*url\((['"]?)(.*?)\1\)/i);
            if (m && m[2]) add(m[2]);
          });

          return Array.from(new Set(out));
        })()
      JS
    )
  rescue StandardError
    []
  end

  def extract_carousel_images_from_browser
    seen = []
    stagnant_rounds = 0

    12.times do
      payload = @browser.evaluate(carousel_extract_js)
      urls = Array(payload["urls"]).filter_map { |u| normalize_image_url(u) }.uniq
      new_seen = (seen + urls).uniq

      stagnant_rounds = new_seen.size == seen.size ? stagnant_rounds + 1 : 0
      seen = new_seen

      clicked = payload["clicked"] == true
      break if !clicked || stagnant_rounds >= 2

      sleep(0.4)
    end

    seen
  rescue StandardError
    []
  end

  def carousel_extract_js
    <<~JS
      (() => {
        const imgUrlsFrom = (root) => {
          const out = [];
          const add = (v) => {
            if (!v) return;
            if (Array.isArray(v)) { v.forEach(add); return; }
            out.push(String(v));
          };
          root.querySelectorAll('img').forEach((img) => {
            add(img.getAttribute('data-zoom-image'));
            add(img.getAttribute('data-large'));
            add(img.getAttribute('data-large-image'));
            add(img.getAttribute('data-src'));
            add(img.getAttribute('src'));
            const srcset = img.getAttribute('srcset') || '';
            srcset.split(',').forEach((entry) => {
              const url = entry.trim().split(/\\s+/)[0];
              if (url) add(url);
            });
          });
          return Array.from(new Set(out));
        };

        const isBookImageUrl = (u) => {
          if (!u) return false;
          const s = String(u);
          // Keep only actual book cover/gallery images.
          return (
            s.includes('BookshopFiles') ||
            s.includes('Bookimg') ||
            s.includes('bookimg')
          );
        };

        const scoreNode = (el) => {
          const imgs = el.querySelectorAll('img');
          if (imgs.length < 2 || imgs.length > 30) return -1;

          // Heuristic: thumbnail rows usually have small visible images.
          let smallCount = 0;
          imgs.forEach((img) => {
            const r = img.getBoundingClientRect();
            if (r.width > 20 && r.width <= 220 && r.height > 20 && r.height <= 220) smallCount += 1;
          });

          const hasNav =
            el.querySelector('.slick-next, [class*="next"], [aria-label*="Next"], button, a') !== null;

          // Prefer containers that include at least 2 book-image URLs.
          const urls = imgUrlsFrom(el).filter(isBookImageUrl);
          if (urls.length < 2) return -1;

          return (smallCount * 10) + urls.length + (hasNav ? 5 : 0);
        };

        const candidates = Array.from(document.querySelectorAll('body *'))
          .filter((el) => el.querySelectorAll && el.querySelectorAll('img').length >= 2);

        let best = null;
        let bestScore = -1;
        for (const el of candidates) {
          const s = scoreNode(el);
          if (s > bestScore) { bestScore = s; best = el; }
        }

        if (!best) return { urls: [], clicked: false };

        const urls = imgUrlsFrom(best).filter(isBookImageUrl);

        const nextSelectors = [
          '.slick-next',
          'button[aria-label*="Next"]',
          'a[aria-label*="Next"]',
          'button[class*="next"]',
          'a[class*="next"]',
          'button[class*="arrow"]',
          'a[class*="arrow"]'
        ];

        let clicked = false;
        for (const sel of nextSelectors) {
          const btn = best.querySelector(sel);
          if (!btn) continue;
          const disabled = btn.disabled || btn.getAttribute('aria-disabled') === 'true' || btn.classList.contains('disabled');
          if (disabled) continue;
          btn.click();
          clicked = true;
          break;
        }

        return { urls, clicked };
      })()
    JS
  end

  def image_urls_from_img(img)
    urls = []

    urls << img["data-zoom-image"]
    urls << img["data-large"]
    urls << img["data-large-image"]
    urls << img["data-src"]
    urls << img["src"]

    srcset = img["srcset"].to_s
    if srcset.present?
      srcset.split(",").each do |entry|
        url = entry.to_s.strip.split(/\s+/).first
        urls << url
      end
    end

    urls
  end

  def normalize_image_url(url)
    u = url.to_s.strip
    return if u.blank?
    return if u.start_with?("data:")

    if u.start_with?("//")
      u = "https:#{u}"
    elsif u.start_with?("/")
      u = "#{BASE_URL}#{u}"
    end

    return unless u.start_with?("http")

    return if u.match?(/icons?/i)
    return if u.include?("cdn.taxmann.com/taxmann-images/bookstore/t_s_p_icons_")
    return if u.match?(%r{/taxmann-images/}i)
    return if u.match?(%r{/(icons?|sprite|logo)[^/]*\.(png|jpg|jpeg|webp|svg)}i)

    u
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
      next unless valid_title?(line)
      return line
    end
    nil
  end

  def extract_author_from_text(text)
    match = text.match(/(?:By|Author)[:\s]+([^\n]{3,100})/i)
    match ? match[1].strip : nil
  end

  def extract_price_from_text(text)
    matches = text.scan(/₹\s*([\d,]+)/)
    return nil if matches.empty?

    prices = matches.map { |m| m[0].gsub(",", "").to_f }
    prices.max
  end

  def extract_prices_and_discount(doc, page_text, product_ld)
    # Try to extract prices and discount from Taxmann's specific layout
    # Typically: Original Price (struck) | Discounted Price (bold) | Discount %

    # First, try to get prices from page text - look for multiple prices
    text_prices = page_text.scan(/₹\s*([\d,]+)/).map { |m| m[0].gsub(",", "").to_f }.sort.reverse

    discount_percent = extract_discount_from_dom(doc) || extract_discount_from_text(page_text)

    if text_prices.size >= 2
      # If we have 2+ prices and a discount %, use them appropriately
      original_price = text_prices[0]  # Highest price
      discounted_price = text_prices[1]  # Second highest

      # Verify the discount % matches
      if discount_percent.present?
        calculated_discount = ((original_price - discounted_price) / original_price * 100).round(1)
        if (calculated_discount - discount_percent.to_f).abs < 2  # Allow 2% tolerance
          return { original_price: original_price, discount_percent: discount_percent }
        end
      end

      # If no discount %, calculate it from the prices
      if original_price > discounted_price
        calculated_discount = ((original_price - discounted_price) / original_price * 100).round(2)
        return { original_price: original_price, discount_percent: calculated_discount }
      end

      return { original_price: original_price, discount_percent: nil }
    elsif text_prices.size == 1
      # Only one price found
      return { original_price: text_prices[0], discount_percent: discount_percent }
    end

    # Fallback: use JSON-LD data
    ld_price = extract_price_from_ld(product_ld)
    return { original_price: ld_price, discount_percent: discount_percent } if ld_price

    { original_price: nil, discount_percent: nil }
  end

  def extract_discount_from_dom(doc)
    # Look for discount percentage in common patterns
    selectors = [
      "[class*='discount']",
      "[class*='Discount']",
      "[class*='off']",
      "[class*='Off']",
      "[class*='sale']",
      "[class*='Sale']"
    ]

    selectors.each do |sel|
      doc.css(sel).each do |node|
        text = node.text.strip
        # Match patterns like "15% Off", "15% off", "15%"
        match = text.match(/(\d+(?:\.\d+)?)\s*%/)
        return match[1].to_f if match
      end
    end

    nil
  end

  def extract_discount_from_text(text)
    # Look for discount percentage in page text
    # Patterns: "15% Off", "15% off", "15% discount"
    match = text.match(/(\d+(?:\.\d+)?)\s*%\s*(?:off|discount|Off|Discount)/i)
    match ? match[1].to_f : nil
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

  def valid_title?(value)
    t = value.to_s.strip
    return false if t.blank?
    return false if t.length < 4 || t.length > 500

    normalized = t.downcase.gsub(/\s+/, " ")
    normalized = normalized.gsub(/[[:punct:]]+\z/, "")

    return false if normalized.match?(/\A(buying options|buy now|add to cart|view content|view sample chapter|quantity|in stock)\b/i)
    return false if normalized.match?(/\A(sign in|log in|cart|menu|home|bookstore|taxmann)\b/i)
    return false if normalized.match?(/\A₹\s*[\d,]+/)
    return false if normalized.match?(/\A(print book|virtual book)\b/i)

    true
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
