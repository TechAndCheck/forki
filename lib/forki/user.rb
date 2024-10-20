# frozen_string_literal: true

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

      def initialize(user_hash = {})
        @name = user_hash[:name]
        @id = user_hash[:id]
        @number_of_followers = user_hash[:number_of_followers]
        @verified = user_hash[:verified]
        @profile = user_hash[:profile]
        @profile_link = user_hash[:profile_link]
        @profile_image_file = user_hash[:profile_image_file]
        @profile_image_url = user_hash[:profile_image_url]
        @number_of_likes = user_hash[:number_of_likes]
      end

      class << self
        private

          def scrape(urls)
            urls.map do |url|
              user_hash = Forki::UserScraper.new.parse(url)
              User.new(user_hash) if user_hash.is_a?(Hash)
            end
          end
      end
  end
end
