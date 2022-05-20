# frozen_string_literal: true

require 'bundler/setup'
require 'tweetkit'
require 'dotenv/load'
require 'net/https'
require 'json'

def lootbox_of_item
  case $lootbox
  when 0..40
    rand($level[1])
  when 40..60
    rand($level[2])
  when 60..80
    rand($level[3])
  when 80..90
    rand($level[4])
  when 90..100
    rand($level[5])
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

items = []

until items.count == 4
  item_id = lootbox_of_item
  p uri = URI.parse("https://teihitsu.deta.dev/items/jyuku_ate/#{item_id}")
  p response = Net::HTTP.get_response(uri)

  if response.code == '200'
    item = JSON.parse(response.body)
    items << item
  end
end

options = []
items.each { |e| options << e['correct_answer'] }
options.shuffle!

p items

question_item = items[0]

client = Tweetkit::Client.new do |config|
  config.consumer_key = ENV['CONSUMER_KEY']
  config.consumer_secret = ENV['CONSUMER_KEY_SECRET']
  config.access_token = ENV['ACCESS_TOKEN']
  config.access_token_secret = ENV['ACCESS_TOKEN_SECRET']
end

response = client.post_tweet(
  text: "次の熟字群・当て字の読みを四択より選べ。\n「#{question_item['problem']}」〈◆#{question_item['level']}｜Q.#{question_item['id']}〉",
  poll: {
    options: options,
    duration_minutes: 120
  }
)

client.post_tweet(
  text: "答えは「#{question_item['correct_answer']}」です。\n\n解説：\n#{question_item['note']}",
  reply: {
    in_reply_to_tweet_id: response.response['data']['id']
  }
)
