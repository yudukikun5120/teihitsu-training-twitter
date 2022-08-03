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
      instance_variable_set "@#{key}", val unless key.empty?
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

  def initialize
    @category = sample_category
    @ctgr_attr, @levels, @probabilities = categories_attr @category
    @level = get_level @levels, @probabilities
    @id = get_problem_id @level, @ctgr_attr
    @problem = Problem.new @category, @id
  end

  def categories_attr(category)
    categories = YAML.load_file './categories.yml'
    ctgr_attr = categories[category]

    levels = ctgr_attr.map { |_, attr| attr['level'] }
    probabilities = ctgr_attr.map { |_, attr| attr['probability'] }

    [ctgr_attr, levels, probabilities]
  end

  def sample_category
    available_category = YAML.load_file('./categories.yml').keys
    available_category.sample
  end

  def get_level(levels, probabilities)
    pyfrom :scipy, import: :stats

    xk = levels
    pk = probabilities
    custm = stats.rv_discrete.call({ values: [xk, pk] })
    custm.rvs
  end

  def get_problem_id(level, ctgr_attr)
    range = ctgr_attr[level]['range']
    start = range['start']
    end_ = range['end']
    (start..end_).to_a.sample
  end

  def get_answer_options(level, shuffle: true)
    answer_options = []
    answer_options << @problem.correct_answer

    until answer_options.count >= 4
      random_id = get_problem_id level, @ctgr_attr
      random_problem = Problem.new @category, random_id
      unless answer_options.include?(random_problem.correct_answer) || random_problem.correct_answer.nil?
        answer_options << random_problem.correct_answer
      end
    end
    answer_options.shuffle! if shuffle
  end

  def set_client
    Tweetkit::Client.new do |config|
      config.consumer_key = ENV.fetch('CONSUMER_KEY', nil)
      config.consumer_secret = ENV.fetch('CONSUMER_KEY_SECRET', nil)
      config.access_token = ENV.fetch('ACCESS_TOKEN', nil)
      config.access_token_secret = ENV.fetch('ACCESS_TOKEN_SECRET', nil)
    end
  end

  def post_tweets
    client = set_client
    answer_options = get_answer_options @level
    tweets = Tweet.new(@category, client, @problem, answer_options)
    res = tweets.first_tweet
    tweets.second_tweet res
    res
  end
end

Tweet = Struct.new(:category, :client, :problem, :answer_options) do
  def question_sentence
    case category
    when 'yoji-kaki'
      '次の四字熟語の下線部に当てはまるものを四択より選べ。'
    when 'jyuku_ate'
      '次の熟字群・当て字の読みを四択より選べ。'
    end
  end

  def first_tweet
    question_sentence =
      case category
      when "yoji-kaki"
        "次の四字熟語の下線部に当てはまるものを四択より選べ。"
      when "jyuku_ate"
        "次の熟字群・当て字の読みを四択より選べ。"
      end

    client.post_tweet(
      text: <<~"TXT",
        #{question_sentence}
        「#{problem.problem}」〈◆#{problem.level}｜Q.#{problem.id}〉
      TXT
      poll: {
        options: answer_options,
        duration_minutes: 300
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

if __FILE__ == $PROGRAM_NAME
  quiz = Quiz.new
  res = quiz.post_tweets
  tweet_url = "https://twitter.com/TeihitsuTRNG/status/#{res.response['data']['id']}"
  puts <<~"LINK"
    the tweet was posted at:
    #{tweet_url}
  LINK
  system "open #{tweet_url}"
end
