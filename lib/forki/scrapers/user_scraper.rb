require "typhoeus"

module Forki
  class UserScraper < Scraper

    # Find how many followers a profile has
    def find_num_followers
      follower_pattern = /Followed by [0-9,.KM ] people/
      alt_follower_pattern = /[0-9,.KM ]+ (f|F)ollowers/

      num_followers_elem = all("span").filter { |span| follower_pattern.match?(span.text)  }.first  # normal profile
      if num_followers_elem.nil?
        num_followers_elem = all("a").filter { |a| alt_follower_pattern.match?(a.text) }.first # "public figure" profile
      end
      extract_int_from_num_element(num_followers_elem)
    end

    # Find how many likes a page has
    def find_num_likes
      likes_pattern = /[0-9,.KM ] people like this/
      num_likes_elem = all("span").filter { | span| likes_pattern.match? span.text }.first
      extract_int_from_num_element(num_likes_elem)
    end

    def find_profile_image(profile_name)
      profile_name_pattern = /#{profile_name}/
      image_parent_element = all("a").find { |a| profile_name_pattern.match?(a["aria-label"]) }
      image_elem = image_parent_element.find("image")

      {
        profile_image_file: Forki.retrieve_media(image_elem["xlink:href"]),
        profile_image_url: image_elem["xlink:href"]
      }
    end

    # Checks whether the current user has a verified profile
    def check_user_is_verified(profile_name)
      begin
        verified_mark = all("i").first { |i| i["aria-label"] == "Verified Account" }
        return validate_verified_mark(verified_mark, profile_name)
      rescue Capybara::ElementNotFound
        return false
      end
    end

    # Checks whether a blue check element is enclosed in an HTML element that contains the current user's profile name
    # May raise Capybara::ElementNotFound
    def validate_verified_mark(elem, profile_name)
      return false if (elem.text != "") &&  (elem.text.strip != profile_name)
      return true if elem.text.strip == profile_name
      validate_verified_mark(elem.find(:xpath, ".."), profile_name)
    end

    def parse(url)
      # Stuff we need to get from the DOM (implemented is starred):
      # - *Name
      # - *Username
      # - *No. of posts
      # - *Verified
      # - *No. of followers
      # - *No. of people they follow
      # - *Profile
      #   - *description
      #   - *links
      # - *Profile image
      url.sub!("m.facebook.com", "www.facebook.com")
      validate_and_load_page(url)

      begin
        profile_name = first("h1").text.strip
      rescue
        profile_name = first("h2").text.strip
      end

      user_data = {
        name: profile_name,
        number_of_likes: find_num_likes,
        number_of_followers: find_num_followers,
        verified: check_user_is_verified(profile_name),
        # profile: graphql_script["entry_data"]["ProfilePage"].first["graphql"]["user"]["biography"],
        profile_link: url
      }
      profile_image_data = find_profile_image(profile_name)
      user_data.update(profile_image_data)
      user_data

    end
  end
end
