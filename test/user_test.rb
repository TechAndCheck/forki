
require "test_helper"

class UserTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  def test_a_public_profile_returns_properly_when_scraped
    urls = %w[https://www.facebook.com/profile.php?id=100044487457347
              https://www.facebook.com/ezraklein]
    users = Forki::User.lookup(urls)
    users.each do |user|
      assert_not_nil user.name
      assert user.number_of_followers > 0
      assert user.number_of_likes.nil?
      assert user.verified

      assert_not_nil user.profile_image_url
      assert_not_nil user.profile_image_file
      assert_not_nil user.profile_link
      assert_not_nil user.id
      assert_not_nil user.profile
    end
  end

  def test_a_page_returns_properly_when_scraped
    urls = %w[https://www.facebook.com/NPR
              https://www.facebook.com/nytimes]
    users = Forki::User.lookup(urls)
    users.each do |user|
      assert_not_nil user.name
      assert user.number_of_followers > 0
      assert user.number_of_likes > 0
      assert user.verified

      assert_not_nil user.profile_image_url
      assert_not_nil user.profile_image_file
      assert_not_nil user.profile_link
      assert_not_nil user.id
      assert_not_nil user.profile
    end
  end

  def test_a_normal_user_profile_returns_properly_when_scraped
    urls = %w[https://www.facebook.com/bill.adair.716
              https://www.facebook.com/mark.stencel]
    users = Forki::User.lookup(urls)
    users.each do |user|
      assert_not_nil user.name

      assert_nil user.number_of_followers
      assert_nil user.number_of_likes
      refute user.verified

      assert_not_nil user.profile_image_url
      assert_not_nil user.profile_image_file
      assert_not_nil user.profile_link
      assert_not_nil user.id
      assert_not_nil user.profile
    end
  end
end
