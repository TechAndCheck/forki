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

    # Returns all GraphQL data objects embedded within a string
    # Finds substrings that look like '"data": {...}' and converts them to hashes
    def find_graphql_data_objects(objs = [], html_str)
      data_marker = '"data":{'
      data_start_index = html_str.index(data_marker)
      return objs if data_start_index.nil? # No more data blocks in the page source

      data_closure_index = find_graphql_data_closure_index(html_str, data_start_index)
      return objs if data_closure_index.nil?

      graphql_data_str = html_str[data_start_index...data_closure_index].delete_prefix('"data":')
      objs + [graphql_data_str] + find_graphql_data_objects(html_str[data_closure_index..])
    end

    def find_graphql_data_closure_index(html_str, start_index)
      ind = start_index + 8 # length of data marker. Begin search right after open brace
      nil if ind > html_str.length

      brace_stack = 1
      loop do  # search for brace characters in substring instead of iterating through each char
        if html_str[ind] == "{"
          brace_stack += 1
          # puts "Brace open: #{brace_stack}"
        elsif html_str[ind] == "}"
          brace_stack -= 1
          # puts "Brace close: #{brace_stack}"
        end

        # brace_stack += 1 if str[ind] == '{'
        # brace_stack -= 1 if str[ind] == '{'
        ind += 1
        break if brace_stack == 0
      end
      ind
    end


    private


    def login
      # Go to the home page
      visit("/")

      return unless all("input", id: "email").length > 0

      fill_in("email", with: ENV["FB_EMAIL"])
      fill_in("Password", with: ENV["FB_PW"])
      click_button("Log In")
      sleep 4
    end

    def validate_and_load_page(url)
      login
      facebook_url_pattern = /https:\/\/www.facebook.com\//
      raise "invalid url" unless facebook_url_pattern.match?(url)
      raise "content unavailable" if all("span").any? { |span| span.text == "This Content Isn't Available Right Now" }
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


    # Extracts an integer out of a string describing a number
    # e.g. "4K Comments" returns 4000
    # e.g. "131 Shares" returns 131
    def extract_int_from_num_element(element)
      return unless element
      if element.class != String
        element = element.text(:all)
      end
      num_pattern = /[0-9KM ,.]+/
      interaction_num_text = num_pattern.match(element)[0]

      if interaction_num_text.include?(".")  # e.g. "2.2K"
        interaction_num_text.to_i + interaction_num_text[-2].to_i * 100
      elsif interaction_num_text.include?("K") # e.g. "13K"
        interaction_num_text.to_i * 1000
      elsif interaction_num_text.include?("M") # e.g. "13M"
        interaction_num_text.to_i * 1_000_000
      else  # e.g. "15,443"
        interaction_num_text.gsub(",", "").gsub(" ", "").to_i
      end
    end

  end
end

require_relative "post_scraper"
require_relative "user_scraper"
