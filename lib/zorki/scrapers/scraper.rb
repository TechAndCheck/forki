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

module Zorki
  class Scraper
    include Capybara::DSL

    # Instagram uses GraphQL (like most of Facebook I think), and returns an object that actually
    # is used to seed the page. We can just parse this for most things.
    #
    # @returns Hash a ruby hash of the JSON data
    def find_num_comments
      comment_pattern = /[0-9KM\. ]+Comments/
      comments_span = all("span").find { |s| s.text(:all) =~ comment_pattern}

      extract_num_interactions(comments_span)
    end


    def find_num_shares
      shares_pattern = /[0-9KM\., ]+Shares/
      spans = all("span")
      shares_span = spans.find { |s| s.text(:all) =~ shares_pattern}

      extract_num_interactions(shares_span)
    end

    def find_num_views
      views_pattern = /[0-9MK, ]+Views/
      spans = all("span")
      views_span = spans.find { | s| s.text =~ views_pattern}

      extract_num_interactions(views_span)

    end

    def extract_num_interactions(element)
      return unless element
      num_pattern = /[0-9KM\.]+/
      interaction_num_text = num_pattern.match(element.text(:all))[0]

      if interaction_num_text.include?(".")  # e.g. "2.2K"
        interaction_num_text.to_i + interaction_num_text[-2].to_i * 100
      elsif interaction_num_text.include?("K") # e.g. "13K"
        interaction_num_text.to_i * 1000
      elsif interaction_num_text.include?("M") # e.g. "13M"
        interaction_num_text.to_i * 1_000_000
      else  # e.g. "15"
        interaction_num_text.to_i
      end
    end

    def find_reactions
      # set threshhold otherwise new reactions will override keys
      reactions = {}
      all("img").find { |s| s["src"] =~ /svg/}.click  # click on a reaction emoji to open countmodal
      popup = find(:xpath, '//div[@aria-label="Reactions"]')  # modal elemeent
      popup_header = popup.first("div")  # modal's first div has reaction counts

      # select divs (containing reaction pictures) with aria-hidden attribute. Throw away the "All" and "More" divs
      reaction_divs = popup_header.all("div", visible: :all).filter { |div| ! (div["aria-hidden"].nil? or div.text.include?("All") or div.text.include?("More")) }

      reaction_divs.each do | div |
        next unless div.all("img", visible: :all).length > 0

        reaction_img = div.find("img", visible: :all)
        reaction_type = determine_reaction_type(reaction_img)
        num_reactions = extract_num_interactions(div)
        reactions[reaction_type.to_sym] = num_reactions
      end
      refresh
      # all("div").find { | div | div["aria-label"] == "Close" }.click  # close reactions modal
      reactions
    end

    def determine_reaction_type(img_elem)
      download_image(img_elem)
      img_hash = DHashVips::IDHash.fingerprint "temp/emoji.png"
      best_match = [nil, 1024]
      Dir.each_child("reactions/") do |filename|
        next unless filename.include? "png"

        match_hash = DHashVips::IDHash.fingerprint "reactions/#{filename}"
        distance = DHashVips::IDHash.distance(img_hash, match_hash)
        if distance < best_match[1]
          best_match = [filename, distance]
        end
      end

      best_match = best_match[0].delete_suffix(".png")
      best_match
    end

    def download_image(img_elem)
      img_data = URI.open(img_elem["src"]).read
      File.binwrite("temp/emoji.png", img_data)
    end

    def find_num_reactions(reaction_elem)
      parent_elem = reaction_elem.find(:xpath, "..")
      reaction_elem.text == "" ? find_num_reactions(parent_elem) : reaction_elem.text.to_i
    end

  private

    def login
      # Go to the home page
      visit("/")

      # Check if we're redirected to a login page, if we aren't we're already logged in
      # return unless page.has_xpath?('//*[@id="loginForm"]/div/div[3]/button')

      fill_in("email", with: ENV["FB_EMAIL"])
      fill_in("Password", with: ENV["FB_PW"])
      click_button("Log In")
      sleep 10

      # No we don't want to save our login credentials
      # click_on("Not Now")
    end

    def fetch_image(url)
      request = Typhoeus::Request.new(url, followlocation: true)
      request.on_complete do |response|
        if request.success?
          return request.body
        elsif request.timed_out?
          raise Zorki::Error("Fetching image at #{url} timed out")
        else
          raise Zorki::Error("Fetching image at #{url} returned non-successful HTTP server response #{request.code}")
        end
      end
    end

  end
end

require_relative "post_scraper"
require_relative "user_scraper"
