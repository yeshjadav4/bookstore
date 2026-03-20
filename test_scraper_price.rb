#!/usr/bin/env ruby
# Run this with: ruby test_scraper_price.rb

require_relative 'config/environment'

url = "https://www.taxmann.com/bookstore/product/40005315-law-practice-series-bns-bnss-bsa"

puts "\n" + "="*90
puts "TESTING PRICE & DISCOUNT EXTRACTION"
puts "="*90
puts "\n🔗 URL: #{url}\n\n"

begin
  scraper = TaxmannScraper.new(url)
  data = scraper.scrape_product_page

  puts "✅ RESULTS:\n"
  puts "  Title:              #{data[:title]}"
  puts "  Author:             #{data[:author]}"
  puts "  Original Price:     ₹#{data[:price]}"
  puts "  Discount Percent:   #{data[:discount_percent]}%"
  
  if data[:price] && data[:discount_percent]
    discounted = (data[:price] * (100 - data[:discount_percent]) / 100.0).round(2)
    puts "  Calculated Discount Price: ₹#{discounted}"
  end
  
  puts "  Images Found:       #{Array(data[:image_urls]).size}"
  puts "\n"

rescue => e
  puts "\n❌ ERROR: #{e.class}"
  puts "   Message: #{e.message}\n\n"
  puts e.backtrace.first(5).join("\n")
end

puts "="*90 + "\n"
