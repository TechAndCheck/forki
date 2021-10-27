# frozen_string_literal: true

require "test_helper"

class PostTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  # Note: if this fails, check the account, the number may just have changed
  # We're using Pete Souza because Obama's former photographer isn't likely to be taken down
  def test_an_image_post_by_a_page_returns_properly_when_scraped
    post = Forki::Post.lookup(["https://www.facebook.com/humansofnewyork/photos/a.102107073196735/6698806303526746/"]).first

    refute post.has_video
    assert_nil post.num_views

    assert post.num_shares > 0
    assert post.num_comments > 0
    assert post.reactions.length > 0

    assert_not_nil post.image_file_name

    assert_not_nil post.user.first
  end

  def test_an_image_post_by_a_user_returns_properly_when_scraped
    post = Forki::Post.lookup(["https://www.facebook.com/photo.php?fbid=3038249389564729&set=a.104631959593168&type=3"]).first
    refute post.has_video
    assert_nil post.num_views  # images do not have "views"

    assert post.num_shares > 0
    assert post.num_comments > 0
    assert post.reactions.length > 0

    assert_not_nil post.image_file_name

    assert_not_nil post.user.first
    assert_not_nil post.creation_date
  end

  def test_a_video_post_by_a_user_returns_properly_when_scraped
    post = Forki::Post.lookup(["https://www.facebook.com/cory.hurlburt/videos/10163562367665117/"]).first
    assert post.has_video
    assert post.num_views > 0

    # assert post.num_shares > 0
    assert post.num_comments > 0
    assert post.reactions.length > 0

    assert_not_nil post.video_file_name
    assert_nil post.image_file_name
    assert_not_nil post.video_preview_image

    assert_not_nil post.user.first
    assert_not_nil post.creation_date
  end

  def test_a_video_post_by_a_page_retuns_properly_when_scraped
    post = Forki::Post.lookup(["https://www.facebook.com/redwhitebluenews/videos/258470355199081/"]).first
    assert post.has_video
    assert post.num_views > 0

    # assert post.num_shares > 0
    assert post.num_comments > 0
    assert post.reactions.length > 0

    assert_not_nil post.video_file_name
    assert_nil post.image_file_name
    assert_not_nil post.video_preview_image

    assert_not_nil post.user.first
    assert_not_nil post.creation_date
  end

  def test_a_video_by_a_page_in_the_watch_tab_returns_properly_when_scraped
    post = Forki::Post.lookup(["https://www.facebook.com/watch/?v=3743756062349219"]).first
    assert post.has_video
    assert post.num_views > 0

    # assert post.num_shares > 0
    assert post.num_comments > 0
    assert post.reactions.length > 0

    assert_not_nil post.video_file_name
    assert_nil post.image_file_name
    assert_not_nil post.video_preview_image

    assert_not_nil post.user.first
    assert_not_nil post.creation_date
  end

  def test_scraping_a_bad_url_raises_invalid_url_exception
    assert_raises "invalid url" do
      Forki::Post.lookup(["https://www.instagram.com/3141592653589"])
    end
  end
end
