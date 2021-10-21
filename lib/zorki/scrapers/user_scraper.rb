# frozen_string_literal: true

require "typhoeus"

module Zorki
  class UserScraper < Scraper
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
      visit url
      # graphql_script = find_graphql_script

      # Get the username (to verify we're on the right page here)

      profile_name = first("h2").text

      # scraped_username = graphql_script["entry_data"]["ProfilePage"].first["graphql"]["user"]["username"]
      # raise Zorki::Error unless username == scraped_username

      # profile_image_url = graphql_script["entry_data"]["ProfilePage"].first["graphql"]["user"]["profile_pic_url_hd"]
      to_return = {
        name: profile_name,
        # username: username,
        # number_of_posts: graphql_script["entry_data"]["ProfilePage"].first["graphql"]["user"]["edge_owner_to_timeline_media"]["count"],
        # number_of_followers: graphql_script["entry_data"]["ProfilePage"].first["graphql"]["user"]["edge_followed_by"]["count"],
        # number_of_following: graphql_script["entry_data"]["ProfilePage"].first["graphql"]["user"]["edge_follow"]["count"],
        # verified: graphql_script["entry_data"]["ProfilePage"].first["graphql"]["user"]["is_verified"],
        # profile: graphql_script["entry_data"]["ProfilePage"].first["graphql"]["user"]["biography"],
        profile_link: url
        # profile_image: Zorki.retrieve_media(profile_image_url),
        # profile_image_url: profile_image_url
      }

      to_return
    end
  end
end
