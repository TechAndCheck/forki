# frozen_string_literal: true

require "test_helper"

# rubocop:disable Metrics/ClassLength
class VideoSieveWatchTabTest < Minitest::Test
  def setup
    @valid_json = JSON.parse(File.read("test/sieves/video_sieves/test_data/video_sieve_watch_tab_valid.json"))
    @invalid_json = JSON.parse(File.read("test/sieves/video_sieves/test_data/video_sieve_watch_tab_invalid.json"))
  end

  def test_sieve_properly_fails_check
    assert VideoSieveWatchTab.check(@invalid_json) == false
  end

  def test_sieve_properly_passes_check
    assert VideoSieveWatchTab.check(@valid_json)
  end

  def test_sieve_can_sieve_properly
    result = VideoSieveWatchTab.sieve(@valid_json)

    assert_equal "394367115960503", result[:id]
    assert_equal 173, result[:num_comments]
    assert_nil result[:num_shared]
    assert_nil result[:num_views]
    assert_equal false, result[:reshare_warning]
    assert_not_nil result[:video_preview_image_url]
    assert_not_nil result[:video_url]
    assert_nil result[:text]
    assert_equal 1654989063, result[:created_at]
    assert_equal "https://www.facebook.com/cookingwithgreens", result[:profile_link]
    assert_equal true, result[:has_video]
    assert_not_nil result[:video_preview_image_file]
    assert_not_nil result[:video_file]
    assert_not_nil result[:reactions]

    assert result[:reactions].kind_of?(Array)
  end
end
