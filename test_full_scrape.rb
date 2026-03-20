#!/usr/bin/env ruby
# Full scraping test - creates/updates book record in database
# Run with: ruby test_full_scrape.rb

require_relative 'config/environment'

url = "https://www.taxmann.com/bookstore/product/40005315-law-practice-series-bns-bnss-bsa"

puts "\n" + "="*90
puts "FULL SCRAPING & SAVING TEST"
puts "="*90
puts "\n🔗 URL: #{url}\n\n"

begin
  # Step 1: Scrape the data
  puts "⏳ Step 1: Scraping data from URL..."
  scraper = TaxmannScraper.new(url)
  data = scraper.scrape_product_page

  puts "✅ Data scraped successfully!\n"
  puts "   Title:        #{data[:title]}"
  puts "   Price:        ₹#{data[:price]}"
  puts "   Discount:     #{data[:discount_percent]}%"
  puts "   Images:       #{Array(data[:image_urls]).size}"
  puts "\n"

  # Step 2: Save to database using the upsert method
  puts "⏳ Step 2: Saving book to database..."
  book = Book.upsert_from_scraped(data)

  puts "✅ Book saved successfully!\n"
  puts "   Book ID:      #{book.id}"
  puts "   Title:        #{book.title}"
  puts "   Price:        ₹#{book.price}"
  puts "   Discount:     #{book.discount_percent}%"
  puts "   Discounted:   ₹#{book.discounted_price}"
  puts "   Images:       #{book.book_images.count}"
  puts "\n"

  # Step 3: Verify images were saved
  puts "⏳ Step 3: Verifying saved images..."
  if book.book_images.any?
    puts "✅ Images saved:\n"
    book.book_images.ordered.each do |img|
      puts "   #{img.sequence}. #{img.image_url[0..60]}..."
    end
  else
    puts "⚠️  No images were saved"
  end

  puts "\n" + "="*90
  puts "✅ TEST COMPLETE - Book record created/updated successfully!"
  puts "="*90 + "\n"

rescue ActiveRecord::RecordInvalid => e
  puts "\n❌ DATABASE ERROR: Record validation failed"
  puts "   Error: #{e.message}\n\n"
  puts e.record.errors.full_messages if e.record
rescue => e
  puts "\n❌ ERROR: #{e.class}"
  puts "   Message: #{e.message}\n\n"
  puts e.backtrace.first(10).join("\n")
end
