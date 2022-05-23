# frozen_string_literal: true

require 'bundler/setup'
require 'tweetkit'
require 'dotenv/load'
require 'net/https'
require 'json'
require 'pycall/import'
require 'yaml'

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
    categories = YAML.load_file './categories.yml'
    @ctgr_attr = categories[category]

    @levels = @ctgr_attr.map { |_, attr| attr['level'] }
    @probabilities = @ctgr_attr.map { |_, attr| attr['probability'] }
    @ranges = @ctgr_attr.map { |_, attr| attr['range'] }

    @level = get_level
  end

  def get_level(levels = @levels, probabilities = @probabilities)
    pyfrom :scipy, import: :stats

    xk = levels
    pk = probabilities
    custm = stats.rv_discrete.call({ values: [xk, pk] })
    custm.rvs
  end

  def get_problem_id(level = @level, ctgr_attr = @ctgr_attr)
    ranges = ctgr_attr[level]['ranges']
    start = ranges['start']
    end_ = ranges['end']
    rand start..end_
  end

  def get_problem(level = @level, category = @category)
    id = get_problem_id level
    Problem.new category, id
  end

  def get_answer_options(level = @level, shuffle: true)
    answer_options = []
    until answer_options.count >= 4
      id = get_problem_id level
      answer_options << Problem.new(category, id).correct_answer
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
    problem = get_problem
    answer_options = get_answer_options
    tweets = Tweet.new(client, problem, answer_options)
    res = tweets.first_tweet
    tweets.second_tweet res
  end
end

Tweet = Struct.new(:client, :problem, :answer_options) do
  def first_tweet
    client.post_tweet(
      text: "次の熟字群・当て字の読みを四択より選べ。\n「#{problem.problem}」〈◆#{problem.level}｜Q.#{problem.id}〉",
      poll: {
        options: answer_options,
        duration_minutes: 120
      }
    )
  end

  def second_tweet(response)
    client.post_tweet(
      text: "答えは「#{problem.correct_answer}」です。\n\n解説：\n#{problem.note}",
      reply: {
        in_reply_to_tweet_id: response.response['data']['id']
      }
    )
  end
end

if __FILE__ == $PROGRAM_NAME
  quiz = Quiz.new 'jyuku_ate'
  quiz.post_tweets
end
