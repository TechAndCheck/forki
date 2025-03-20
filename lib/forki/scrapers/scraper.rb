# frozen_string_literal: true

# require_relative "user_scraper"
require "capybara/dsl"
require "dotenv/load"
require "oj"
require "selenium-webdriver"
require "open-uri"
require "selenium/webdriver/remote/http/curb"
require "cgi"

options = Selenium::WebDriver::Options.chrome(exclude_switches: ["enable-automation"])
options.add_argument("--start-maximized")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("–-disable-blink-features=AutomationControlled")
options.add_argument("--disable-extensions")
options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36")
options.add_preference "profile.password_manager_enabled", false
options.add_preference "credentials_enable_service", false
options.add_preference "profile.default_content_setting_values.notifications", 2
options.add_argument("--disable-dev-shm-usage")
options.add_argument("--remote-debugging-port=9222")
options.add_argument("--user-data-dir=/tmp/tarun_forki_#{SecureRandom.uuid}")

Capybara.register_driver :selenium_forki do |app|
  client = Selenium::WebDriver::Remote::Http::Curb.new
  # client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, http_client: client)
end

Capybara.default_max_wait_time = 60
Capybara.threadsafe = true
Capybara.reuse_server = true

module Forki
  class Scraper # rubocop:disable Metrics/ClassLength
    include Capybara::DSL
    attr_reader :logged_in

    def initialize
      Capybara.default_driver = :selenium_forki
      Forki.set_logger_level
      @logged_in = false
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
      options = Selenium::WebDriver::Options.chrome(exclude_switches: ["enable-automation"])
      options.add_argument("--start-maximized")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("–-disable-blink-features=AutomationControlled")
      options.add_argument("--disable-extensions")
      options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36")
      options.add_preference "password_manager_enabled", false
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--remote-debugging-port=9222")
      options.add_argument("--user-data-dir=/tmp/tarun_forki_#{SecureRandom.uuid}")

      Capybara.register_driver :selenium_forki do |app|
        client = Selenium::WebDriver::Remote::Http::Curb.new
        # client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, http_client: client)
      end

      Capybara.current_driver = :selenium_forki
    end

    # Logs in to Facebook (if not already logged in)
    def login(url = nil)
      raise MissingCredentialsError if ENV["FACEBOOK_EMAIL"].nil? || ENV["FACEBOOK_PASSWORD"].nil?

      url ||= "https://www.facebook.com"

      load_saved_cookies

      page.driver.browser.navigate.to(url)  # Visit the url passed in or the facebook homepage if nothing is

      # Look for "login_form" box, which throws an error if not found. So we catch it and run the rest of the tests
      begin
        login_form = first(id: "login_form", wait: 5)
      rescue Capybara::ElementNotFound
        begin
          login_form = find(:xpath, '//form[@data-testid="royal_login_form"]')
        rescue Capybara::ElementNotFound
          return unless page.title.downcase.include?("facebook - log in")
        end
      end

      # Since we're not logged in, let's do that quickly
      if login_form.nil?
        page.driver.browser.navigate.to("https://www.facebook.com")

        # Find the login form... again (Yes, we could extract this out, but it's only ever used
        # here, so it's not worth the effort)
        begin
          login_form = first(id: "login_form", wait: 5)
        rescue Capybara::ElementNotFound
          begin
            login_form = find(:xpath, '//form[@data-testid="royal_login_form"]')
          rescue Capybara::ElementNotFound
            return unless page.title.downcase.include?("facebook - log in")
          end
        end
      end

      if login_form.nil?
        # maybe we're already logged in?
        sleep(rand * 10.3)
        return
      end

      login_form.fill_in("email", with: ENV["FACEBOOK_EMAIL"])
      login_form.fill_in("pass", with: ENV["FACEBOOK_PASSWORD"])

      # This is a pain because some pages just `click_button` would work, but some won't
      login_buttons = login_form.all("div", text: "Log In", wait: 5)

      if login_buttons.empty?
        login_form.click_button("Log In")
      else
        login_buttons.each do |button|
          if button.text == "Log In"
            button.click
            break
          end
        end
      end

      begin
        raise Forki::BlockedCredentialsError if find_by_id("error_box", wait: 3)
      rescue Capybara::ElementNotFound; end

      # Now we wait awhile, hopefully to slow down scraping
      @logged_in = true

      save_cookies
      sleep(rand * 10.3)
    end

    def logout
      first(:xpath, "//div[@aria-label='Your profile']").click
      first("span", text: "Log Out").click()
      @logged_in = false
    end

    # Ensures that a valid Facebook url has been provided, and that it points to an available post
    # If either of those two conditions are false, raises an exception
    def validate_and_load_page(url)
      Capybara.app_host = "https://www.facebook.com"
      facebook_hosts = ["facebook.com", "www.facebook.com", "web.facebook.com", "m.facebook.com", "l.facebook.com"]
      parsed_url = URI.parse(url)
      host = parsed_url.host
      raise Forki::InvalidUrlError.new("Invalid Facebook host: #{host}") unless facebook_hosts.include?(host)

      # Replace the host with a default one to prevent redirect loops that can happen
      unless parsed_url.host == "www.facebook.com"
        parsed_url.host = "www.facebook.com"
        url = parsed_url.to_s
      end

      # If the url is a shared embed, the main url should be extracted
      if url.start_with?("https://www.facebook.com/plugins/post.php")
        query = URI(url).query
        raise Forki::InvalidUrlError.new("Invalid Facebook post embed url") if query.nil?
        decoded_query = URI.decode_www_form(query)
        elemental_url = decoded_query.find { |u| u[0] == "href" if u.is_a?(Array) }
        raise Forki::InvalidUrlError.new("Invalid Facebook post embed url") if elemental_url.nil?
        href = elemental_url[1] if elemental_url.is_a?(Array)
        raise Forki::InvalidUrlError.new("Invalid Facebook post embed url") if href.nil?
        url = href
      end

      visit url # unless current_url.start_with?(url)

      # Let's check if we need to try to login first
      begin
        content_unavailable_flag = !find("span", text: "This content isn't available right now", wait: 2).nil?
      rescue Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
        content_unavailable_flag = false
      end

      if content_unavailable_flag
        visit("https://www.facebook.com")
        login if !logged_in
      end # Find and close a dialog if possible, aria-label="Close"

      visit(url) # I have no idea why this is out here, but it has to be otherwise looking up a user after a log out fails
      # This isn't strictly necessary since we're already looking up a post first, but for testing... yeah

      # # If the video is a watch page it doesn't have most of the data we want so we click on the video
      # if url.include?("watch/live")
      #   clickable_element = find("video")

      #   while(clickable_element.obscured?)
      #     clickable_element = clickable_element.find(:xpath, "..")
      #   end

      #   clickable_element.click
      # end
    end

    # Extracts an integer out of a string describing a number
    # e.g. "4K Comments" returns 4000
    # e.g. "131 Shares" returns 131
    def self.extract_int_from_num_element(element)
      return unless element

      if element.class != String # if an html element was passed in
        element = element.text(:all)
      end

      # Check if there's a modifier i.e. `K` or `M` if there isn't just return the number
      unless element.include?("K") || element.include?("M")
        element.delete(",") # "5,456" e.g.
        return element.to_i
      end

      modifier = element[-1]
      number = element[0...-1].to_f

      case modifier
      when "K"
        number = number * 1_000
      when "M"
        number = number * 1_000_000
      end

      number.to_i
    end

    def save_cookies
      puts "Saving cookies..."
      cookies_json = page.driver.browser.manage.all_cookies.to_json
      File.write("forki_cookies.json", cookies_json)
    end

    def load_saved_cookies
      return unless File.exist?("forki_cookies.json")

      cookies_json = File.read("forki_cookies.json")
      cookies = JSON.parse(cookies_json, symbolize_names: true)
      cookies.each do |cookie|
        cookie[:expires] = Time.parse(cookie[:expires]) unless cookie[:expires].nil?
        begin
          puts "Loading coookies..."
          page.driver.browser.manage.add_cookie(cookie)

        rescue StandardError => e
          puts "Error loading cookies: #{e}"
        end
      end
      puts "Refreshing page..."
      page.driver.browser.navigate.refresh
    end
  end
end

require_relative "post_scraper"
require_relative "user_scraper"
