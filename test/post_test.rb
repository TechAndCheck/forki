# frozen_string_literal: true

require "test_helper"

# rubocop:disable Metrics/ClassLength
class PostTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  def test_an_image_post_by_a_page_returns_properly_when_scraped
    urls = %w[https://www.facebook.com/381726605193429/photos/a.764764956889590/3625268454172545/
              https://www.facebook.com/police.thinblueline/photos/a.10151517985262372/10158540959247372/
              https://www.facebook.com/photo?fbid=924035232421621&set=a.833599168131895]
    posts = Forki::Post.lookup(urls)
    posts.each do |post|
      assert post.has_video == false
      assert_nil post.num_views # images do not have views

      assert_predicate post.num_shares, :positive?
      assert_predicate post.num_comments, :positive?
      assert_predicate post.reactions.length, :positive?

      assert_not_nil post.image_file
      assert_not_nil post.screenshot_file
      assert_nil post.video_file

      assert_not_nil post.user
      assert_not_nil post.created_at
      assert_not_nil post.id
    end
  end

  def test_that_a_post_with_web_dot_facebook_scrapes
    urls = %w[https://web.facebook.com/381726605193429/photos/a.764764956889590/3625268454172545/]

    posts = Forki::Post.lookup(urls)

    assert_equal 1, posts.count
  end

  def test_that_a_video_post_in_a_comment_thread_is_detected_correctly
    urls = %w[https://www.facebook.com/PlandemicMovie/videos/588866298398729/]

    posts = Forki::Post.lookup(urls)

    posts.each do |post|
      assert post.has_video
      # assert post.num_views > 0  # live videos may not have views listed

      assert_predicate post.num_comments, :positive?
      assert_predicate post.reactions.length, :positive?

      assert_not_nil post.video_file
      assert_not_nil post.video_preview_image_file
      assert_not_nil post.screenshot_file
      assert_nil post.image_file

      assert_not_nil post.user
      assert_not_nil post.created_at
    end
  end

  def test_an_image_post_by_a_user_returns_properly_when_scraped
    urls = %w[https://www.facebook.com/photo.php?fbid=10213343702266063
              https://www.facebook.com/photo.php?fbid=3038249389564729
              https://www.facebook.com/photo.php?fbid=10217495563806354]
    posts = Forki::Post.lookup(urls)
    posts.each do |post|
      assert post.has_video == false
      assert_nil post.num_views

      assert_predicate post.num_shares, :positive?
      assert_predicate post.num_comments, :positive?
      assert_predicate post.reactions.length, :positive?

      assert_not_nil post.image_file
      assert_not_nil post.screenshot_file

      assert_not_nil post.user
      assert_not_nil post.created_at
    end
  end

  def test_a_video_post_by_a_user_returns_properly_when_scraped
    posts = Forki::Post.lookup("https://www.facebook.com/Meta/videos/264436895517475")
    posts.each do |post|
      assert post.has_video
      assert_predicate post.num_views, :positive?

      assert_predicate post.num_comments, :positive?
      assert_predicate post.reactions.length, :positive?

      assert_not_nil post.video_file
      assert_not_nil post.video_preview_image_file
      assert_not_nil post.screenshot_file
      assert_nil post.image_file

      assert_not_nil post.user
      assert_not_nil post.created_at
    end
  end

  def test_a_video_post_by_a_page_retuns_properly_when_scraped
    urls = %w[https://www.facebook.com/161453087348302/videos/684374025476745/
              https://www.facebook.com/AmericaFirstAction/videos/323018088749144/
              https://www.facebook.com/Meta/videos/264436895517475]
    posts = Forki::Post.lookup(urls)
    posts.each do |post|
      assert post.has_video

      assert_predicate post.num_comments, :positive?
      assert_predicate post.reactions.length, :positive?

      assert_not_nil post.video_file
      assert_not_nil post.video_preview_image_file
      assert_not_nil post.screenshot_file
      assert_nil post.image_file

      assert_not_nil post.user
      assert_not_nil post.created_at
    end
  end

  def test_a_video_in_the_watch_tab_returns_properly_when_scraped
    urls = %w[https://www.facebook.com/watch/?v=2707731869527520
              https://www.facebook.com/watch/?v=3743756062349219]
    posts = Forki::Post.lookup(urls)
    posts.each do |post|
      assert post.has_video
      assert_predicate post.num_views, :positive?

      assert_predicate post.num_comments, :positive?
      assert_predicate post.reactions.length, :positive?

      assert_not_nil post.video_file
      assert_not_nil post.video_preview_image_file
      assert_not_nil post.screenshot_file
      assert_nil post.image_file

      assert_not_nil post.user
      assert_not_nil post.created_at
    end
  end

  # These don't seem to be a thing anymore?
  # def test_a_live_video_in_the_watch_tab_returns_properly_when_scraped
  #   urls = %w[https://www.facebook.com/watch/live/?v=394367115960503]
  #   posts = Forki::Post.lookup(urls)
  #   posts.each do |post|
  #     assert post.has_video

  #     assert post.num_comments.positive?
  #     assert post.reactions.length.positive?

  #     assert_not_nil post.video_file
  #     assert_not_nil post.screenshot_file
  #     assert_not_nil post.video_preview_image_file
  #     assert_nil post.image_file

  #     assert_not_nil post.user
  #     assert_not_nil post.created_at
  #   end
  # end

  def test_a_video_works
    urls = %w[https://www.facebook.com/iwhidby/videos/957333404980798/?__cft__[0]=AZUs48ZqIBsbNqva5zUJvziRhA7W-GJi8O_b1IXB20maEjdiBpmL8_w27Ghpl1b7pp-9UmFGtAfYQFh6KKDP7MUGO9jHGc0PZyae-MeA7-DEBEbZGNoxPaO2GQSukEx8VyIXm2y2UOw4j616U600XkNQ&__tn__=%2CO%2CP-R]
    posts = Forki::Post.lookup(urls)
    posts.each do |post|
      assert post.has_video

      assert_predicate post.num_comments, :positive?
      assert_predicate post.reactions.length, :positive?

      assert_not_nil post.video_file
      assert_not_nil post.screenshot_file
      assert_not_nil post.video_preview_image_file
      assert_nil post.image_file

      assert_not_nil post.user
      assert_not_nil post.created_at
    end
  end

  def test_scraping_a_bad_url_raises_invalid_url_exception
    assert_raises "invalid url" do
      Forki::Post.lookup("https://www.instagram.com/3141592653589")
    end
  end

  def test_scraping_an_inaccessible_post_raises_a_content_not_available_exception
    assert_raises Forki::ContentUnavailableError do
      Forki::Post.lookup("https://www.facebook.com/redwhitebluenews/videos/258470355199081/")
    end
  end

  def test_scraping_a_taken_down_post_raises_a_content_not_available_exception
    assert_raises Forki::ContentUnavailableError do
      Forki::Post.lookup("https://www.facebook.com/photo.php?fbid=10163749206915113&set=a.329268060112&type=3&theater/")
    end
  end

  def test_various_domain_types
    post = Forki::Post.lookup("https://www.facebook.com/shalikarukshan.senadheera/posts/pfbid0287di3uHqt6s8ARUcuY7fNyyP86xEsvg7yjmn9v4eG1QLMrikwAPKvNoDy4Pynjtjl?_rdc=1&_rdr").first

    assert_equal false, post.has_video

    assert_predicate post.num_comments, :positive?
    assert_predicate post.reactions.length, :positive?

    assert_nil post.video_file
    assert_not_nil post.screenshot_file
    assert_nil post.video_preview_image_file
    assert_not_nil post.image_file

    assert_not_nil post.user
    assert_not_nil post.created_at
  end

  def test_reel
    # https://www.facebook.com/reel/809749953859034
    post = Forki::Post.lookup("https://www.facebook.com/reel/809749953859034").first
    assert_not_nil(post)
  end

  def test_reel_other_format
    post = Forki::Post.lookup("https://www.facebook.com/share/r/jh5LX4CNhPXxn83F/").first
    assert_not_nil(post)
  end

  # Not sure why this is here, it's not a link that works
  # def test_another_link
  #   Forki::Post.lookup("https://www.facebook.com/manuelbuffa84/posts/pfbid02uqbifnKoRhW6Z9T1EBNXAnH5uyn9khWjPtfUYZPrLfkdjxtpTqpj521doA6Aa51ol")
  # end

  def test_another_link_2
    post = Forki::Post.lookup("https://www.facebook.com/bonifacemusavulivh/posts/1800353787146024/").first

    assert post.has_video

    assert_predicate post.num_comments, :positive?
    assert_predicate post.reactions.length, :positive?

    assert_not_nil post.video_file
    assert_not_nil post.screenshot_file
    assert_not_nil post.video_preview_image_file
    assert_nil post.image_file

    assert_not_nil post.user
    assert_not_nil post.created_at
  end

  def test_another_link_3
    Forki::Post.lookup("https://www.facebook.com/icheck.tn/posts/pfbid02VmRj1WEajyKJVHnQxiuDDjGAJr3h1RHWekp1Z3a999RpBjat9d1XJAww999rLzUvl")
  end

  def test_a_pure_text_link
    post = Forki::Post.lookup("https://www.facebook.com/TobiszowskiGrzegorz/posts/pfbid09xYce8UagCCFqZLFqqM5SqnuwoKCA4tW5XSUQsEHJL5XHJAgpvjkFxK1BaxsmhEul")
    assert !post.first.text.empty?
    assert_predicate post.first.text.length, :positive?
  end

  def test_an_alternative_reel
    Forki::Post.lookup("https://www.facebook.com/reel/2841887882618164")
  end

  def test_a_url_that_seems_to_fail
    Forki::Post.lookup("https://www.facebook.com/mydefiguru/posts/2857725071050020/")
  end

  def test_a_url_that_seems_to_fail_2
    Forki::Post.lookup("https://www.facebook.com/DonaldTrump/posts/pfbid09yccynLeptpTGdCzWnfGAqN6RH1eUg6WYo4jAekcvqvDJ4zrv4mFmkHoFB8cKed5l")
  end

  def test_a_url_that_seems_to_fail_3
    Forki::Post.lookup("https://www.facebook.com/share/p/19JjhuYDjy/")
  end
end
