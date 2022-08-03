# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'main'

# Test the main.rb file
class TestMain < Minitest::Unit::TestCase
  def test_category_sampling
    quizzes = []
    10.times do
      quizzes << Quiz.new
    end

    assert_equal quizzes.map(&:category).include?('yoji-kaki'), true
    assert_equal quizzes.map(&:category).include?('jyuku_ate'), true
  end
end
