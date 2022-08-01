# frozen_string_literal: true

module Forki
  class Post
    def self.lookup(urls = [])
      urls = [urls] unless urls.kind_of?(Array)
      self.scrape(urls)
    end

    attr_reader :image_file,
                :image_url,
                :has_video,
                :url,
                :id,
                :num_comments,
                :num_shares,
                :num_views,
                :reactions,
                :text,
                :created_at,
                :user,
                :video_file,
                :video_preview_image_file,
                :video_preview_image_url,
                :screenshot_file

  private

    def initialize(post_hash = {})
      # I need to figure out what's up with Facebook ids. Media have unique IDs, but their position in the URL is variable
      # @id = post_hash[:id]
      @image_file = post_hash[:image_file]
      @image_url = post_hash[:image_url]
      @has_video = post_hash[:has_video]
      @url = post_hash[:url]
      @id = post_hash[:id]
      @num_comments = post_hash[:num_comments]
      @num_shares = post_hash[:num_shares]
      @num_views = post_hash[:num_views]
      @reactions = post_hash[:reactions]
      @text = post_hash[:text]
      @created_at = post_hash[:created_at]
      @user = post_hash[:user]
      @video_file = post_hash[:video_file]
      @video_preview_image_file = post_hash[:video_preview_image_file]
      @video_preview_image_url = post_hash[:video_preview_image_url]
      @screenshot_file = post_hash[:screenshot_file]
    end

    class << self
      private

        def scrape(urls)
          urls.map do |url|
            post_hash = Forki::PostScraper.new.parse(url)
            Post.new(post_hash)
          end
        end
    end
  end
end
