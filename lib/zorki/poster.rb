# frozen_string_literal: true

require "byebug"
module Zorki
  class Poster
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the usernames are at least real usernames
      # usernames.each { |id| raise Birdsong::Error if !/\A\d+\z/.match(id) }

      self.scrape(ids)
    end

    attr_reader :name,
                :username,
                :number_of_posts,
                :number_of_followers,
                :number_of_following,
                :verified,
                :profile,
                :profile_link,
                :profile_image,
                :profile_image_url

    private

    def initialize(hash = {})
      @name = hash[:name]
      # @username = hash[:username]
      # @number_of_posts = hash[:number_of_posts]
      # @number_of_followers = hash[:number_of_followers]
      # @number_of_following = hash[:number_of_following]
      # @verified = hash[:verified]
      # @profile = hash[:profile]
      @profile_link = hash[:profile_link]
      # @profile_image = hash[:profile_image]
      # @profile_image_url = hash[:profile_image_url]
    end

    class << self
      private

      def scrape(ids)
        ids.map do |id|
          poster_hash = Zorki::UserScraper.new.parse(id)
          Poster.new(poster_hash)
        end
      end
    end
  end
end
