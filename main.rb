require 'httparty'
require 'json'
require 'pry'

def with_time_measure(description)
  start = Time.now
  puts "Starting #{description}"
  result = yield
  puts "Time taken #{(Time.now-start)} seconds"
  result
end

def with_retry(description)
  begin
    tries = 0
    with_time_measure(description) do
      yield
    end
  rescue => e
    puts e
    tries += 1
    if tries < 3
      puts "Retrying..."
      retry
    end
  end
end

POLAND_ID = 142
START_PAGE = 1
PAGES = 100 # change this to fetch more pages :)

def parse_date(date)
  match = /(.*), (.*)/.match(date)
  if match
    [match[1], match[2]]
  else
    raise "invalid date provided  #{date}"
  end
end

stats = []
warn = 0
(START_PAGE..PAGES).each do |page|
  crawl = with_retry "crawl page #{page}" do
    HTTParty.get("https://hidden-earth-2612.herokuapp.com/crawl/#{page}")
  end

  begin
    articles = JSON.parse(crawl.body)
  rescue
    puts "Could not parse json"
    puts crawl.body
    next
  end

  articles.each do |article|
    entities = with_retry "analyze #{article['title']}" do
      HTTParty.post('http://quiet-shelf-9562.herokuapp.com/analyze/', body: {
        content: [article["title"], article["content"], article["extended_content"]].join(" ")[0..250]
      })
    end

    cities = entities["cities"]
    sources = cities.find_all { |c| c["country_id"] == POLAND_ID }.uniq
    destinations = cities.find_all { |c| c["country_id"] != POLAND_ID }.uniq
    prices = [article["title"], article["content"]].join(" ").scan(/\d+ PLN/).uniq
    airlines = entities["airlines"].map { |a| a["base_form"] }.uniq.join(", ")

    puts "destinations count #{destinations.size}"
    destinations = destinations.select { |dest| article["tags"].find { |t| t.downcase == dest["base_form"].downcase } }
    puts "destinations count in tags #{destinations.size}"

    if destinations.size > 0
      if sources.size > 0
        puts "From #{sources.map { |c| c["base_form"] }.join(", ")}"
      end

      puts "To #{destinations.map { |c| c["base_form"] }.join(", ")}"

      if prices.size > 0
        puts "For #{prices.join(", ")}"
      end

      if airlines.size > 0
        puts "By #{airlines}"
      end

      puts "Posted on #{article["date"]}"
      puts "--------\n"

      # FILL stats
      parsed_date = parse_date(article["date"])
      stats << {
        sources: sources.map { |c| c["id"] },
        destinations: destinations.map { |c| c["id"] },
        airlines: entities["airlines"].map { |a| a["id"] }.uniq,
        prices: prices,
        comments_count: article["comments"].size,
        max_comment_rating: article["comments"].map { |c| c["rank"] }.max.to_i,
        min_comment_rating: article["comments"].map { |c| c["rank"] }.min.to_i,
        date: parsed_date[0],
        time: parsed_date[1]
      }
    end
  end
  puts stats.to_json
  puts "---"
end

puts stats.to_json
