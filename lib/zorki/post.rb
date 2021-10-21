# frozen_string_literal: true

module Zorki
  class Post
    def self.lookup(urls = [])
      # If a single id is passed in we make it the appropriate array
      urls = [urls] unless urls.kind_of?(Array)

      # Check that the urls are at least real urls
      # urls.each { |id| raise Birdsong::Error if !/\A\d+\z/.match(id) }

      self.scrape(urls)
    end

    attr_reader :image_file_name,
                # :id,
                :image_url,
                :has_video,
                :url,
                :num_comments,
                :num_shares,
                :num_views,
                :reactions,
                :text,
                :date,
                :user,
                :video_file_name,
                :video_preview_image,
                :video_preview_image_url

  private

    def initialize(hash = {})
      # I need to figure out what's up with Facebook ids. Media have unique IDs, but their position in the URL is variable
      # @id = hash[:id]
      @image_file_name = hash[:image_file_name]
      @image_url = hash[:image_url]
      @has_video = hash[:has_video]
      @url = hash[:url]
      @num_comments = hash[:num_comments]
      @num_shares = hash[:num_shares]
      @num_views = hash[:num_views]
      @reactions = hash[:reactions]
      @text = hash[:text]
      @date = hash[:date]
      @user = hash[:user]
      @video_file_name = hash[:video]
      @video_preview_image = hash[:video_preview_image]
      @video_preview_image_url = hash[:video_preview_image_url]
    end

    class << self
      private

      def scrape(urls)
        urls.map do |url|
          post_hash = Zorki::PostScraper.new.parse(url)
            Post.new(post_hash)
          end
        end
    end
  end
end
