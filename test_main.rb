require "minitest/autorun"
require_relative 'main'

class TestMain < Minitest::Unit::TestCase
    def test_category_sampling
        quizzes = []
        10.times do
            quizzes << Quiz.new
        end

        assert_equal quizzes.map{|quiz| quiz.category}.include?("yoji-kaki"), true
        assert_equal quizzes.map{|quiz| quiz.category}.include?("jyuku_ate"), true
    end
end
