# frozen_string_literal: true

require "byebug"
module Forki
  class User
    def self.lookup(urls = [])
      urls = [urls] unless urls.kind_of?(Array)
      self.scrape(urls)
    end

    attr_reader :name,
                :id,
                :number_of_followers,
                :verified,
                :profile,
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
      @profile = hash[:profile]
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
