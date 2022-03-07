require "bundler/setup"
require 'tweetkit'
require 'dotenv/load'
require 'net/https'


def lootbox_of_item
  case $lootbox
  when 0..40
    return rand($level[1])
  when 40..60
    return rand($level[2])
  when 60..80
    return rand($level[3])
  when 80..90
    return rand($level[4])
  when 90..100
    return rand($level[5])
  end
end


$level = {
  1 => 1..459,
  2 => 460..1362,
  3 => 1363..1755,
  4 => 1756..2101,
  5 => 2102..2184
}

$lootbox = rand(0..100)

items = Array.new()

until items.count == 4 do
  item_id = lootbox_of_item
  p uri = URI.parse("https://teihitsu.deta.dev/items/jyuku-ate/#{item_id}")
  p response = Net::HTTP.get_response(uri)

  if response.code == "200"
    item = JSON.parse(response.body)
    items << item
  end
end

options = Array.new()
items.each { |e| options << e["a"] }
options.shuffle!

question_item = items[0]

client = Tweetkit::Client.new do |config|
  config.consumer_key = ENV["CONSUMER_KEY"]
  config.consumer_secret = ENV["CONSUMER_KEY_SECRET"]
  config.access_token = ENV["ACCESS_TOKEN"]
  config.access_token_secret = ENV["ACCESS_TOKEN_SECRET"]
end

p response = client.post_tweet(
  text: "次の熟字群・当て字の読みを四択より選べ。\nQ.#{question_item["item_id"]}「#{question_item["q"]}」",
  poll: {
    options: options,
    duration_minutes: 120
  }
)

p response = client.post_tweet(
  text: "答えは「#{question_item["a"]}」です。\n\n解説：\n#{question_item["comment"]}",
  reply: {
    in_reply_to_tweet_id: response.response["data"]["id"],
  }
)
