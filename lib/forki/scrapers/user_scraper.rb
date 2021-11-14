require "typhoeus"

module Forki
  class UserScraper < Scraper

    # Find how many likes a page has
    def find_num_likes
      likes_pattern = /[0-9,.KM ] people like this/
      num_likes_elem = all("span").filter { | span| likes_pattern.match? span.text }.first
      extract_int_from_num_element(num_likes_elem)
    end

    # strip away paranthetical nicknames
    def clean_profile_name(profile_name)
    end

    def find_num_followers(profile_details_str)
      followers_pattern = /Followed by (?<num_followers>[0-9,.KM ]) people/
      alt_follower_pattern = /(?<num_followers>[0-9,.KM ]+) (f|F)ollowers/
      num_followers_match = followers_pattern.match(profile_details_str) || alt_follower_pattern.match(profile_details_str)
      return nil if num_followers_match.nil?
      extract_int_from_num_element(num_followers_match.named_captures["num_followers"])
    end

    def extract_profile_details(gql_strs)
      profile_header_str = gql_strs.find {|gql| gql.include? "profile_header_renderer" }
      profile_header_obj = JSON.parse(profile_header_str)["user"]["profile_header_renderer"]
      profile_title_sections_str = gql_strs.find { |gql| gql.include? "show_prevet_blue_badge_modal_ig_verified" }
      # profile_title_sections_obj = JSON.parse(profile_title_sections_str)
      {
        id: profile_header_obj["user"]["id"],
        number_of_followers: find_num_followers(profile_title_sections_str),
        name: profile_header_obj["user"]["name"],
        verified: profile_header_obj["user"]["is_verified"],
        profile_image_url: profile_header_obj["user"]["profilePhoto"]["url"],
      }
    end

    def extract_page_details(gql_strs)
      page_cards_str = gql_strs.find { |gql| (gql.include? "comet_page_cards") && (gql.include? "follower_count")}
      page_cards_list = JSON.parse(page_cards_str)["page"]["comet_page_cards"]
      page_about_card = page_cards_list.find { |card| card["__typename"] == "CometPageAboutCardWithoutMapRenderer" }
      viewer_page_obj = JSON.parse(gql_strs.find { |gql| (gql.include? "profile_photo") && gql.include?("is_verified") })
      {
        id: page_about_card["page"]["id"],
        number_of_followers: page_about_card["page"]["follower_count"],
        name: page_about_card["page"]["name"],
        verified: viewer_page_obj["page"]["is_verified"],
        profile_image_url: viewer_page_obj["page"]["profile_photo"]["url"],
        number_of_likes: page_about_card["page"]["page_likers"]["global_likers_count"],
      }
    end

    def parse(url)
      # Stuff we need to get from the DOM (implemented is starred):
      # - *Name
      # - *No. of followers
      # - *Verified
      # - *Profile image

      url.sub!("m.facebook.com", "www.facebook.com")
      validate_and_load_page(url)

      gql_strs = find_graphql_data_strings(page.html)
      is_page = gql_strs.map { |s| JSON.parse(s) }.any? {|o| o.keys.include?("page") }
      user_details = is_page ? extract_page_details(gql_strs) : extract_profile_details(gql_strs)

      user_details[:profile_image_file] = Forki.retrieve_media(user_details[:profile_image_url])
      user_details[:profile_link] = url
      user_details
    end
  end
end
