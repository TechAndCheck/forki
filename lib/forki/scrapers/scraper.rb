# frozen_string_literal: true

# require_relative "user_scraper"
require "capybara/dsl"
require "dotenv/load"
require "oj"
require "selenium-webdriver"
require "open-uri"

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument("--window-size=1500,1500")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("--user-data-dir=/tmp/tarun_forki_#{SecureRandom.uuid}")

Capybara.register_driver :selenium_forki do |app|
  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
  Capybara::Selenium::Driver.new(app, browser: :chrome, url: "http://localhost:4444/wd/hub", capabilities: options, http_client: client)
end

Capybara.default_max_wait_time = 60
Capybara.threadsafe = true
Capybara.reuse_server = true

module Forki
  class Scraper
    include Capybara::DSL

    def initialize
      Capybara.default_driver = :selenium_forki
      Forki.set_logger_level
      # reset_selenium
    end

    # Yeah, just use the tmp/ directory that's created during setup
    def download_image(img_elem)
      img_data = URI.open(img_elem["src"]).read
      File.binwrite("temp/emoji.png", img_data)
    end

    # Returns all GraphQL data objects embedded within a string
    # Finds substrings that look like '"data": {...}' and converts them to hashes
    def find_graphql_data_strings(objs = [], html_str)
      data_marker = '"data":{'
      data_start_index = html_str.index(data_marker)
      return objs if data_start_index.nil? # No more data blocks in the page source

      data_closure_index = find_graphql_data_closure_index(html_str, data_start_index)
      return objs if data_closure_index.nil?

      graphql_data_str = html_str[data_start_index...data_closure_index].delete_prefix('"data":')
      objs + [graphql_data_str] + find_graphql_data_strings(html_str[data_closure_index..])
    end

    def find_graphql_data_closure_index(html_str, start_index)
      closure_index = start_index + 8 # length of data marker. Begin search right after open brace
      raise "Malformed graphql data object: no closing bracket found" if closure_index > html_str.length

      brace_stack = 1
      loop do  # search for brace characters in substring instead of iterating through each char
        if html_str[closure_index] == "{"
          brace_stack += 1
        elsif html_str[closure_index] == "}"
          brace_stack -= 1
        end

        closure_index += 1
        break if brace_stack.zero?
      end

      closure_index
    end

  private

    ##########
    # Set the session to use a new user folder in the options!
    # #####################
    def reset_selenium
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--window-size=1500,1500")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--user-data-dir=/tmp/tarun_forki_#{SecureRandom.uuid}")

      Capybara.register_driver :selenium_forki do |app|
        client = Selenium::WebDriver::Remote::Http::Default.new
        client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
        Capybara::Selenium::Driver.new(app, browser: :chrome, url: "http://localhost:4444/wd/hub", capabilities: options, http_client: client)
      end

      Capybara.current_driver = :selenium_forki
    end

    # Logs in to Facebook (if not already logged in)
    def login
      raise MissingCredentialsError if ENV["FACEBOOK_EMAIL"].nil? || ENV["FACEBOOK_PASSWORD"].nil?

      page.quit

      visit("https://www.facebook.com")  # Visit the Facebook home page
      return unless page.title.downcase.include?("facebook - log in")  # We should only see this page title if we aren't logged in

      fill_in("email", with: ENV["FACEBOOK_EMAIL"])
      fill_in("pass", with: ENV["FACEBOOK_PASSWORD"])
      click_button("Log In")

      begin
        raise Forki::BlockedCredentialsError if find_by_id("error_box", wait: 3)
      rescue Capybara::ElementNotFound; end
    end

    # Ensures that a valid Facebook url has been provided, and that it points to an available post
    # If either of those two conditions are false, raises an exception
    def validate_and_load_page(url)
      Capybara.app_host = "https://www.facebook.com"
      facebook_url = "https://www.facebook.com"
      visit "https://www.facebook.com" unless current_url.start_with?(facebook_url)
      login
      raise Forki::InvalidUrlError unless url.start_with?(facebook_url)
      visit url
    end

    # Extracts an integer out of a string describing a number
    # e.g. "4K Comments" returns 4000
    # e.g. "131 Shares" returns 131
    def extract_int_from_num_element(element)
      return unless element

      if element.class != String # if an html element was passed in
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
        interaction_num_text.delete!(",")
        interaction_num_text.delete(" ").to_i
      end
    end
  end
end

require_relative "post_scraper"
require_relative "user_scraper"
