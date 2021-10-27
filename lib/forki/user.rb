# frozen_string_literal: true

require "byebug"
module Forki
  class User
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the usernames are at least real usernames
      # usernames.each { |id| raise Birdsong::Error if !/\A\d+\z/.match(id) }

      self.scrape(ids)
    end

    attr_reader :name,
                :number_of_followers,
                :verified,
                # :profile,
                :profile_link,
                :profile_image_file,
                :profile_image_url,
                :number_of_likes

    private

    # More next week
    def initialize(hash = {})
      @name = hash[:name]
      @number_of_followers = hash[:number_of_followers]
      @verified = hash[:verified]
      # @profile = hash[:profile]
      @profile_link = hash[:profile_link]
      @profile_image_file = hash[:profile_image_file]
      @profile_image_url = hash[:profile_image_url]
      @number_of_likes = hash[:number_of_likes]
    end

    class << self
      private

      def scrape(urls)
        urls.map do |url|
          user_hash = Forki::UserScraper.new.parse(url)
          User.new(user_hash)
        end
      end
    end
  end
end
