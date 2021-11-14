# frozen_string_literal: true

require "byebug"
module Forki
  class User
    def self.lookup(url)
      self.scrape(url)
    end

    attr_reader :name,
                :id,
                :number_of_followers,
                :verified,
                :profile_link,
                :profile_image_file,
                :profile_image_url,
                :number_of_likes

    private

    def initialize(hash = {})
      @name = hash[:name]
      @id = hash[:id]
      @number_of_followers = hash[:number_of_followers]
      @verified = hash[:verified]
      @profile_link = hash[:profile_link]
      @profile_image_file = hash[:profile_image_file]
      @profile_image_url = hash[:profile_image_url]
      @number_of_likes = hash[:number_of_likes]
    end

    class << self
      private

      def scrape(url)
        user_hash = Forki::UserScraper.new.parse(url)
        User.new(user_hash)
      end
    end
  end
end
