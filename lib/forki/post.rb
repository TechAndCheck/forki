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
                :video_preview_image_url

  private

    def initialize(hash = {})
      # I need to figure out what's up with Facebook ids. Media have unique IDs, but their position in the URL is variable
      # @id = hash[:id]
      @image_file = hash[:image_file]
      @image_url = hash[:image_url]
      @has_video = hash[:has_video]
      @url = hash[:url]
      @id = hash[:id]
      @num_comments = hash[:num_comments]
      @num_shares = hash[:num_shares]
      @num_views = hash[:num_views]
      @reactions = hash[:reactions]
      @text = hash[:text]
      @created_at = hash[:created_at]
      @user = hash[:user]
      @video_file = hash[:video_file]
      @video_preview_image_file = hash[:video_preview_image_file]
      @video_preview_image_url = hash[:video_preview_image_url]
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
