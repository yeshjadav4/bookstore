#!/usr/bin/env ruby
require_relative 'config/environment'

url = "https://www.taxmann.com/bookstore/product/40005315-law-practice-series-bns-bnss-bsa"

puts "\n" + "="*80
puts "DEBUGGING SCRAPER FOR: #{url}"
puts "="*80 + "\n"

begin
  scraper = TaxmannScraper.new(url)
  
  puts "🔍 Starting browser and navigating to URL..."
  data = scraper.scrape_product_page
  
  puts "\n✅ SCRAPING RESULTS:\n"
  puts "  Title:        #{data[:title].inspect}"
  puts "  Author:       #{data[:author].inspect}"
  puts "  Price:        #{data[:price]}"
  puts "  Discount %:   #{data[:discount_percent]}"
  puts "  Images found: #{Array(data[:image_urls]).size}"
  puts "  First image:  #{data[:image_url].inspect}"
  puts "\n📸 All images:"
  Array(data[:image_urls]).each_with_index do |url, idx|
    puts "    #{idx + 1}. #{url}"
  end
  
  puts "\n📋 Full data hash:"
  data.each do |key, value|
    next if key == :image_urls # Skip the full list for readability
    puts "  #{key}: #{value.inspect}"
  end
  
rescue => e
  puts "\n❌ ERROR: #{e.class} - #{e.message}"
  puts e.backtrace.first(10).join("\n")
end

puts "\n" + "="*80 + "\n"
