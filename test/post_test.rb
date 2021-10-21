# frozen_string_literal: true

require "test_helper"

class PostTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  # Note: if this fails, check the account, the number may just have changed
  # We're using Pete Souza because Obama's former photographer isn't likely to be taken down
  def test_a_single_image_post_returns_properly_when_scraped
    post = Zorki::Post.lookup(["https://www.facebook.com/humansofnewyork/photos/a.102107073196735/6698806303526746/"]).first
    assert_equal post.image_file_names.count, 1
  end

end
