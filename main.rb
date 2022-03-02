require "bundler/setup"
require 'tweetkit'
require 'dotenv/load'
require 'net/https'


MAX_ITEM_ID = 2184

# 項目を保存する配列
@items = []

until @items.count == 4 do
  item_id = rand(1..MAX_ITEM_ID)
  p uri = URI.parse("https://teihitsu.deta.dev/items/jyuku-ate/#{item_id}")
  p response = Net::HTTP.get_response(uri)

  if response.code == "200"
    item = JSON.parse(response.body)
    @items << item
  end
end

options = Array.new()
@items.each { |e| options << e["a"] }
options.shuffle!

question_item = @items[0]

client = Tweetkit::Client.new do |config|
  config.consumer_key = ENV["CONSUMER_KEY"]
  config.consumer_secret = ENV["CONSUMER_KEY_SECRET"]
  config.access_token = ENV["ACCESS_TOKEN"]
  config.access_token_secret = ENV["ACCESS_TOKEN_SECRET"]
end

p client.post_tweet(
  text: "次の熟字群・当て字の読みを四択より選べ。\nQ.#{question_item["item_id"]}「#{question_item["q"]}」",
  poll: {
    options: options,
    duration_minutes: 120
  }
)
