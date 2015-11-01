require 'httparty'
require 'json'
require 'pry'

POLAND_ID = 142

def parse_date(date)
  match = /(\d+) (\S+) (\d+), (\d+):(\d+)/.match(date)
  if match
    "#{match[4].to_i}:#{match[5].to_i}"
  else
    raise "invalid date provided  #{date}"
  end
end

stats = []
(1..30).each do |page|

  crawl = HTTParty.get("https://hidden-earth-2612.herokuapp.com/crawl/#{page}")
  articles = JSON.parse(crawl.body)
  puts "Articles fetched. Analyzing..."
  articles.each do |article|
    entities = HTTParty.post('http://quiet-shelf-9562.herokuapp.com/analyze/', body: {
      content: [article["title"], article["content"], article["extended_content"]].join(" ")[0..250]
    })
    cities = entities["cities"]
    sources = cities.find_all { |c| c["country_id"] == POLAND_ID }.map { |c| c["base_form"] }.uniq.join(", ")
    destinationes = cities.find_all { |c| c["country_id"] != POLAND_ID }.map { |c| c["base_form"] }.uniq.join(", ")
    prices = article["content"].scan(/\d+ PLN/).join(", ")
    airlines = entities["airlines"].map { |a| a["base_form"] }.uniq.join(", ")

    if destinationes.size > 0
      if sources.size > 0
        puts "From #{sources}"
      end

      puts "To #{destinationes}"

      if prices.size > 0
        puts "For #{prices}"
      end

      if airlines.size > 0
        puts "By #{airlines}"
      end

      puts "Posted on #{article["date"]}"
      puts "--------\n"

      # FILL stats
      stats << {
        cities: cities.map { |c| c["id"]}.uniq,
        airlines: entities["airlines"].map { |a| a["id"] }.uniq,
        prices: prices,
        time: parse_date(article["date"])
      }
    end


  end
end

puts stats.to_json
