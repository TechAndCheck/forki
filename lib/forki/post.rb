# frozen_string_literal: true

module Forki
  class Post
    def self.lookup(url)
      self.scrape(url)
    end

    attr_reader :image_file_name,
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
                :video_file_name,
                :video_preview_image_file_name,
                :video_preview_image_url

  private

    def initialize(hash = {})
      # I need to figure out what's up with Facebook ids. Media have unique IDs, but their position in the URL is variable
      # @id = hash[:id]
      @image_file_name = hash[:image_file_name]
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
      @video_file_name = hash[:video_file_name]
      @video_preview_image_file_name = hash[:video_preview_image_file_name]
      @video_preview_image_url = hash[:video_preview_image_url]
    end

    class << self
      private

      def scrape(url)
        post_hash = Forki::PostScraper.new.parse(url)
          Post.new(post_hash)
        end
    end
  end
end
