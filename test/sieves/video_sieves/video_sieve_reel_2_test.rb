# frozen_string_literal: true

require "test_helper"

# rubocop:disable Metrics/ClassLength
class VideoSieveReelTest < Minitest::Test
  def setup
    @valid_json = JSON.parse(File.read("test/sieves/video_sieves/test_data/video_sieve_reel_2_valid.json"))
    @invalid_json = JSON.parse(File.read("test/sieves/video_sieves/test_data/video_sieve_reel_2_invalid.json"))
  end

  def test_sieve_properly_fails_check
    assert VideoSieveReel.check(@invalid_json) == false
  end

  def test_sieve_properly_passes_check
    assert VideoSieveReel.check(@valid_json)
  end

  def test_sieve_can_sieve_properly
    result = VideoSieveReel.sieve(@valid_json)

    # TODO: Update the values for the post you're testing
    assert_equal "809749953859034", result[:id]
    assert_equal 1078, result[:num_comments]
    assert_equal 8100, result[:num_shared]
    assert_nil result[:num_views]
    assert_equal true, result[:reshare_warning]
    assert_not_nil result[:video_preview_image_url]
    assert_not_nil result[:video_url]
    assert_nil result[:text]
    assert_equal 1689646427, result[:created_at]
    assert_equal "https://www.facebook.com/cathy.christian.9889", result[:profile_link]
    assert_equal true, result[:has_video]
    assert_not_nil result[:video_preview_image_file]
    assert_not_nil result[:video_file]
    assert_nil result[:reactions]
  end
end
