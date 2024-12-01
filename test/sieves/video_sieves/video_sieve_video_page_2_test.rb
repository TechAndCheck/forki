# frozen_string_literal: true

require "test_helper"

# rubocop:disable Metrics/ClassLength
class VideoSieveVideoPageTest < Minitest::Test
  def setup
    @valid_json = JSON.parse(File.read("test/sieves/video_sieves/test_data/video_sieve_video_page_2_valid.json"))
    @invalid_json = JSON.parse(File.read("test/sieves/video_sieves/test_data/video_sieve_video_page_2_invalid.json"))
  end

  def test_sieve_properly_fails_check
    assert VideoSieveVideoPage.check(@invalid_json) == false
  end

  def test_sieve_properly_passes_check
    assert VideoSieveVideoPage.check(@valid_json)
  end

  def test_sieve_can_sieve_properly
    result = VideoSieveVideoPage.sieve(@valid_json)

    # TODO: Update the values for the post you're testing
    assert_equal "588866298398729", result[:id]
    assert_equal 46, result[:num_comments]
    assert_equal 485, result[:num_shared]
    assert_nil result[:num_views]
    assert_equal true, result[:reshare_warning]
    assert_not_nil result[:video_preview_image_urls]
    assert_not result[:video_preview_image_urls].empty?
    assert_not_nil result[:video_url]
    assert_equal "Infectious disease expert Dr. Anthony Fauci tells 60 Minutes: \"There's no reason to be walking around with a mask.\"\n\n🎥 60 Minutes", result[:text]
    assert_equal 1588777850, result[:created_at]
    assert_equal "https://www.facebook.com/PlandemicMovie", result[:profile_link]
    assert_equal true, result[:has_video]
    assert_not_nil result[:video_preview_image_files]
    assert_not_nil result[:video_files]
    assert_not_nil result[:reactions]

    assert result[:reactions].kind_of?(Array)
  end
end
