
require "test_helper"

class UserTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  def test_a_public_figure_profile_returns_properly_when_scraped
    user = Forki::User.lookup(["https://www.facebook.com/ezraklein"]).first
    assert_equal user.name, "Ezra Klein"
    assert user.number_of_followers >= 1_000_000
    assert user.number_of_likes.nil?
    assert user.verified

    refute user.profile_image_url.nil?
    refute user.profile_image_file.nil?
    refute user.profile_link.nil?
  end

  def test_a_normal_user_profile_returns_properly_when_scraped
    user = Forki::User.lookup(["https://www.facebook.com/bill.adair.716"]).first
    assert_equal user.name, "Bill Adair"

    assert user.number_of_followers.nil?
    assert user.number_of_likes.nil?
    refute user.verified

    refute user.profile_image_url.nil?
    refute user.profile_image_file.nil?
    refute user.profile_link.nil?
  end

  def test_a_page_returns_properly_when_scraped
    user = Forki::User.lookup(["https://www.facebook.com/nytimes"]).first
    assert_equal user.name, "The New York Times"

    assert user.number_of_likes > 10_000_000
    assert user.verified

    refute user.profile_image_url.nil?
    refute user.profile_image_file.nil?
    refute user.profile_link.nil?
  end

end
