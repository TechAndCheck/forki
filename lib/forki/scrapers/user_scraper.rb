require "typhoeus"

module Forki
  class UserScraper < Scraper
    # Finds and returns the number of people who like the current page
    def find_number_of_likes
      likes_pattern = /[0-9,.KM ] people like this/
      number_of_likes_elem = all("span").filter { | span| likes_pattern.match? span.text }.first
      extract_int_from_num_element(number_of_likes_elem)
    end

    # Finds and returns the number of people who follow the current page
    def find_number_of_followers(profile_details_string)
      followers_pattern = /Followed by (?<num_followers>[0-9,.KM ]) people/
      alt_follower_pattern = /(?<num_followers>[0-9,.KM ]+) (f|F)ollowers/
      number_of_followers_match = followers_pattern.match(profile_details_string) || alt_follower_pattern.match(profile_details_string)
      return nil if number_of_followers_match.nil?
      extract_int_from_num_element(number_of_followers_match.named_captures["num_followers"])
    end

    def find_number_followers_for_normal_profile(profile_followers_node)
      followers_string = profile_followers_node["node"]["timeline_context_item"]["renderer"]["context_item"]["title"]["text"]
      followers_pattern = /[0-9,]+/
      number_of_followers_match = followers_pattern.match(followers_string).to_s
      extract_int_from_num_element(number_of_followers_match)
    end

    # Returns a hash of details about a Facebook user profile
    def extract_profile_details(graphql_strings)
      profile_header_str = graphql_strings.find { |gql| gql.include? "profile_header_renderer" }
      profile_intro_str = graphql_strings.find { |g| g.include? "profile_intro_card" }
      profile_header_obj = JSON.parse(profile_header_str)["user"]["profile_header_renderer"]
      profile_intro_obj = profile_intro_str ? JSON.parse(profile_intro_str) : nil

      number_of_followers = find_number_of_followers(profile_header_str)

      # Check if the user shows followers count
      if number_of_followers.nil?
        profile_title_section = graphql_strings.find { |gql| gql.include? "profile_tile_section_type" }

        json = JSON.parse(profile_title_section)
        followers_node = json["user"]["profile_tile_sections"]["edges"].first["node"]["profile_tile_views"]["nodes"][1]["view_style_renderer"]["view"]["profile_tile_items"]["nodes"].select do |node|
          node["node"]["timeline_context_item"]["timeline_context_list_item_type"] == "INTRO_CARD_FOLLOWERS"
        end
        if followers_node.empty?
          number_of_followers = nil
        else
          number_of_followers = find_number_followers_for_normal_profile(followers_node.first)
        end
      end


      {
        id: profile_header_obj["user"]["id"],
        number_of_followers: number_of_followers,
        name: profile_header_obj["user"]["name"],
        verified: profile_header_obj["user"]["is_verified"],
        profile: profile_intro_obj ? profile_intro_obj["profile_intro_card"]["bio"]["text"] : "",
        profile_image_url: profile_header_obj["user"]["profilePicLarge"]["uri"],
      }
    end

    # Returns a hash of details about a Facebook page
    def extract_page_details(graphql_strings)
      page_cards_string = graphql_strings.find { |graphql_string| (graphql_string.include? "comet_page_cards") && \
                                                                  (graphql_string.include? "follower_count")}
      page_cards_list = JSON.parse(page_cards_string)["page"]["comet_page_cards"]
      page_about_card = page_cards_list.find { |card| card["__typename"] == "CometPageAboutCardWithoutMapRenderer" }
      viewer_page_object = JSON.parse(graphql_strings.find { |graphql_string| (graphql_string.include? "profile_photo") && \
                                                                               graphql_string.include?("is_verified") })
      {
        id: page_about_card["page"]["id"],
        profile: page_about_card["page"]["page_about_fields"]["blurb"],
        number_of_followers: page_about_card["page"]["follower_count"],
        name: page_about_card["page"]["name"],
        verified: viewer_page_object["page"]["is_verified"],
        profile_image_url: viewer_page_object["page"]["profile_picture"]["uri"],
        number_of_likes: page_about_card["page"]["page_likers"]["global_likers_count"],
      }
    end

    # Uses GraphQL data and DOM elements to collect information about the current user page
    def parse(url)
      validate_and_load_page(url)
      graphql_strings = find_graphql_data_strings(page.html)
      is_page = graphql_strings.map { |s| JSON.parse(s) }.any? { |o| o.keys.include?("page") }
      user_details = is_page ? extract_page_details(graphql_strings) : extract_profile_details(graphql_strings)

      page.quit

      user_details[:profile_image_file] = Forki.retrieve_media(user_details[:profile_image_url])
      user_details[:profile_link] = url
      user_details
    end
  end
end
