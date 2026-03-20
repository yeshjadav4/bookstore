#!/usr/bin/env ruby
# Check scraping setup and create if needed
# Run with: ruby check_scraping_setup.rb

require_relative 'config/environment'

puts "\n" + "="*90
puts "SCRAPING SETUP CHECK"
puts "="*90 + "\n"

url = "https://www.taxmann.com/bookstore/product/40005315-law-practice-series-bns-bnss-bsa"

# Check 1: ScrapingUrl records
puts "📋 Checking ScrapingUrl records...\n"
scraping_urls = ScrapingUrl.all
if scraping_urls.any?
  puts "✅ Found #{scraping_urls.size} ScrapingUrl(s):\n"
  scraping_urls.each do |su|
    puts "   ID #{su.id}: #{su.url_type} - #{su.url[0..70]}"
    puts "     Label: #{su.label || '(none)'}"
    puts "     Active: #{su.active}"
    puts "     Last scraped: #{su.last_scraped_at || 'Never'}"
    puts ""
  end
else
  puts "⚠️  No ScrapingUrl records found!\n"
  puts "   Creating one for: #{url}\n\n"
  
  su = ScrapingUrl.create!(
    url: url,
    url_type: :product,
    label: "Law & Practice Trio (Test)",
    active: true
  )
  
  puts "✅ Created ScrapingUrl ID #{su.id}\n"
end

# Check 2: Books in database
puts "\n📚 Checking Books in database...\n"
books = Book.order(created_at: :desc).limit(5)
if books.any?
  puts "✅ Found #{Book.count} total books. Last 5:\n"
  books.each do |book|
    puts "   ID #{book.id}: #{book.title[0..50]}"
    puts "     Price: ₹#{book.price} (Discount: #{book.discount_percent}%)"
    puts "     Images: #{book.book_images.count}"
    puts ""
  end
else
  puts "⚠️  No books found in database\n"
end

# Check 3: ScrapeLog records
puts "\n📊 Checking ScrapeLog records...\n"
logs = ScrapeLog.order(created_at: :desc).limit(5)
if logs.any?
  puts "✅ Found #{ScrapeLog.count} total logs. Last 5:\n"
  logs.each do |log|
    status = log.status == 0 ? "✅ SUCCESS" : "❌ FAILURE"
    puts "   #{log.created_at.strftime('%Y-%m-%d %H:%M:%S')} - #{status}"
    puts "     Books found: #{log.books_found}"
    puts "     Duration: #{log.duration_seconds.round(2)}s"
    puts "     Error: #{log.error_message}" if log.error_message.present?
    puts ""
  end
else
  puts "⚠️  No ScrapeLog records found\n"
end

puts "="*90 + "\n"
