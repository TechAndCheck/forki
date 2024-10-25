# frozen_string_literal: true

require "test_helper"

# rubocop:disable Metrics/ClassLength
class PostTest < Minitest::Test
  def setup
    @valid_json = JSON.parse(File.read("test/sieves/video_sieves/test_data/video_sieve_watch_tab_valid.json"))
    @invalid_json = JSON.parse(File.read("test/sieves/video_sieves/test_data/video_sieve_watch_tab_invalid.json"))
  end

  def test_sieve_can_sieve_properly
    VideoSieve.sieve_for_graphql_objects(@valid_json)
  end
end
