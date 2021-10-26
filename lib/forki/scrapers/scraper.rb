# frozen_string_literal: true

# require_relative "user_scraper"
require "capybara/dsl"
require "dotenv/load"
require "oj"
require "selenium-webdriver"
require "open-uri"
require "dhash-vips"

Capybara.default_driver = :selenium_chrome
Capybara.app_host = "https://facebook.com"
Capybara.default_max_wait_time = 15

module Forki
  class Scraper
    include Capybara::DSL

    # Yeah, just use the tmp/ directory that's created during setup
    def download_image(img_elem)
      img_data = URI.open(img_elem["src"]).read
      File.binwrite("temp/emoji.png", img_data)
    end


  private

    def login
      # Go to the home page
      visit("/")

      return unless all("input", id: "email").length > 0

      fill_in("email", with: ENV["FB_EMAIL"])
      fill_in("Password", with: ENV["FB_PW"])
      click_button("Log In")
      sleep 10
    end

    def validate_and_load_page(url)
      login
      facebook_url_pattern = /https:\/\/www.facebook.com\//
      raise "invalid url" unless facebook_url_pattern.match?(url)
      visit url
    end

    def fetch_image(url)
      request = Typhoeus::Request.new(url, followlocation: true)
      request.on_complete do |response|
        if request.success?
          return request.body
        elsif request.timed_out?
          raise forki::Error("Fetching image at #{url} timed out")
        else
          raise forki::Error("Fetching image at #{url} returned non-successful HTTP server response #{request.code}")
        end
      end
    end

  end
end

require_relative "post_scraper"
require_relative "user_scraper"
