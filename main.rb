# frozen_string_literal: true

require 'bundler/setup'
require 'tweetkit'
require 'dotenv/load'
require 'net/https'
require 'json'
require 'pycall/import'
require 'yaml'
require 'optparse'

# define a problem
class Problem
  attr_reader :id, :problem, :level, :correct_answer, :alt_correct_answers, :note

  def initialize(category, id)
    @category = category
    @id = id
    get_content(@category, @id).each_pair do |key, val|
      instance_variable_set("@#{key}", val)
    end
  end

  def get_content(category, id)
    uri = URI.parse "https://teihitsu.deta.dev/items/#{category}/#{id}"
    response = Net::HTTP.get_response uri
    JSON.parse response.body
  end
end

# define a quiz
class Quiz
  include PyCall::Import

  attr_reader :category, :levels, :ctgr_attr

  def initialize(category)
    @category = category
    categories_attr @category
    level @levels, @probabilities
    @id = get_problem_id @level, @ctgr_attr
    @problem = Problem.new @category, @id
  end

  def categories_attr=(category)
    categories = YAML.load_file './categories.yml'
    ctgr_attr = categories[category]

    levels = ctgr_attr.map { |_, attr| attr['level'] }
    probabilities = ctgr_attr.map { |_, attr| attr['probability'] }

    @ctgr_attr = ctgr_attr
    @levels = levels
    @probabilities = probabilities
  end

  def level=(levels, probabilities)
    pyfrom :scipy, import: :stats

    xk = levels
    pk = probabilities
    custm = stats.rv_discrete.call({ values: [xk, pk] })
    @level = custm.rvs
  end

  def get_problem_id(level, ctgr_attr)
    range = ctgr_attr[level]['range']
    start = range['start']
    end_ = range['end']
    rand start..end_
  end

  def get_answer_options(level, shuffle: true)
    answer_options = []
    answer_options << @problem.correct_answer

    until answer_options.count >= 4
      random_id = get_problem_id level, @ctgr_attr
      answer_options << Problem.new(@category, random_id).correct_answer
    end
    answer_options.shuffle! if shuffle
    answer_options
  end

  def set_client
    Tweetkit::Client.new do |config|
      config.consumer_key = ENV['CONSUMER_KEY']
      config.consumer_secret = ENV['CONSUMER_KEY_SECRET']
      config.access_token = ENV['ACCESS_TOKEN']
      config.access_token_secret = ENV['ACCESS_TOKEN_SECRET']
    end
  end

  def post_tweets
    client = set_client
    answer_options = get_answer_options @level
    tweets = Tweet.new(client, @problem, answer_options)
    res = tweets.first_tweet
    tweets.second_tweet res
    res
  end
end

Tweet = Struct.new(:client, :problem, :answer_options) do
  def first_tweet
    client.post_tweet(
      text: <<~"TXT",
        次の熟字群・当て字の読みを四択より選べ。
        「#{problem.problem}」〈◆#{problem.level}｜Q.#{problem.id}〉
      TXT
      poll: {
        options: answer_options,
        duration_minutes: 120
      }
    )
  end

  def second_tweet(response)
    client.post_tweet(
      text: <<~"TXT",
        答えは「#{problem.correct_answer}」です。

        解説：
        #{problem.note}
      TXT
      reply: {
        in_reply_to_tweet_id: response.response['data']['id']
      }
    )
  end
end

def category(category = nil)
  opt = OptionParser.new
  opt.on('-c', '--category CATEGORY', 'specify the category') { |v| category ||= v }
  opt.parse!(ARGV)

  category
end

if __FILE__ == $PROGRAM_NAME
  quiz = Quiz.new category
  res = quiz.post_tweets
  puts <<~"LINK"
    the tweet was posted at:
    https://twitter.com/TeihitsuTRNG/status/#{res.response['data']['id']}
  LINK
end
