books_data = [
  {
    title: "Taxmann's Direct Taxes Manual",
    author: "Taxmann's Editorial Board",
    price: 3495.00,
    isbn: "9789356228726",
    publisher: "Taxmann Publications",
    edition: "2026 Edition",
    pages: 2400,
    category: "Direct Tax",
    description: "Comprehensive compilation of all direct tax laws, rules, circulars and notifications.",
    image_url: nil,
    source_url: "https://www.taxmann.com/bookstore/product/direct-taxes-manual",
    reviews_count: 42,
    rating: 4.5
  },
  {
    title: "GST Manual with GST Law Guide",
    author: "Taxmann's Editorial Board",
    price: 2995.00,
    isbn: "9789356228733",
    publisher: "Taxmann Publications",
    edition: "14th Edition",
    pages: 1800,
    category: "GST",
    description: "Contains the complete GST law with commentary, analysis and all related rules.",
    image_url: nil,
    source_url: "https://www.taxmann.com/bookstore/product/gst-manual",
    reviews_count: 38,
    rating: 4.3
  },
  {
    title: "Income Tax Act",
    author: "Taxmann's Editorial Board",
    price: 1895.00,
    isbn: "9789356228740",
    publisher: "Taxmann Publications",
    edition: "71st Edition",
    pages: 1500,
    category: "Direct Tax",
    description: "The Income Tax Act as amended by the Finance Act 2026.",
    image_url: nil,
    source_url: "https://www.taxmann.com/bookstore/product/income-tax-act",
    reviews_count: 55,
    rating: 4.7
  },
  {
    title: "Company Law",
    author: "Dr. G.K. Kapoor, Sanjay Dhamija",
    price: 850.00,
    isbn: "9789356228757",
    publisher: "Taxmann Publications",
    edition: "25th Edition",
    pages: 900,
    category: "Corporate Law",
    description: "A comprehensive textbook on company law covering all provisions of the Companies Act.",
    image_url: nil,
    source_url: "https://www.taxmann.com/bookstore/product/company-law",
    reviews_count: 30,
    rating: 4.2
  },
  {
    title: "Mysterious Temples of India - Coffee-table Book",
    author: "Taxmann's Editorial Board",
    price: 2550.00,
    isbn: "9789356228764",
    publisher: "Taxmann Publications",
    edition: "1st Edition",
    pages: 200,
    category: "General Reading",
    description: "A stunning visual journey through India's most mysterious and awe-inspiring temples.",
    image_url: nil,
    source_url: "https://www.taxmann.com/bookstore/product/mysterious-temples",
    reviews_count: 12,
    rating: 4.8
  },
  {
    title: "Stock Market Wisdom",
    author: "T.S. Anantharaman",
    price: 470.00,
    isbn: "9789356228771",
    publisher: "Taxmann Publications",
    edition: "2nd Edition",
    pages: 320,
    category: "General Reading",
    description: "Practical insights and strategies for intelligent stock market investing.",
    image_url: nil,
    source_url: "https://www.taxmann.com/bookstore/product/stock-market-wisdom",
    reviews_count: 18,
    rating: 4.0
  },
  {
    title: "Auditing & Assurance",
    author: "Pankaj Garg",
    price: 995.00,
    isbn: "9789356228788",
    publisher: "Taxmann Publications",
    edition: "9th Edition",
    pages: 750,
    category: "Accounts & Audit",
    description: "Covers auditing principles and assurance standards for CA students and professionals.",
    image_url: nil,
    source_url: "https://www.taxmann.com/bookstore/product/auditing-assurance",
    reviews_count: 22,
    rating: 4.1
  },
  {
    title: "Cyber Crimes & Financial Offences - Practical Solution",
    author: "All India Federation of Tax Practitioners",
    price: 1295.00,
    isbn: "9789356228795",
    publisher: "Taxmann Publications",
    edition: "1st Edition",
    pages: 450,
    category: "Criminal Law",
    description: "Practical solutions for dealing with cyber crimes and financial offences in India.",
    image_url: nil,
    source_url: "https://www.taxmann.com/bookstore/product/cyber-crimes",
    reviews_count: 5,
    rating: 4.4
  }
]

books_data.each do |data|
  Book.upsert_from_scraped(data)
end

puts "Seeded #{books_data.size} books."
