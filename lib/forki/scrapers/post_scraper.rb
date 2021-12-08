# frozen_string_literal: true

require "typhoeus"

module Forki
  class PostScraper < Scraper

    # Searches the DOM to finds the number of times a (video) post has been viewed.
    # Returns nil if it can't find a DOM element with the view count
    def find_number_of_views
      views_pattern = /[0-9MK, ]+Views/
      spans = all("span")
      views_span = spans.find { | s| s.text(:all) =~ views_pattern}
      extract_int_from_num_element(views_span)
    end

    def extract_post_data(graphql_strings)
      graphql_objects = graphql_strings.map { |graphql_object| JSON.parse(graphql_object) }
      post_has_video = graphql_objects.any? { |graphql_object| graphql_object.keys.include?("video") }
      post_has_video ? extract_video_post_data(graphql_strings) : extract_image_post_data(graphql_objects)
    end

    # Unfortunately, there's a taxonomy of video post types, all of which require different parsing methods
    # Specifically, there are normal video posts, video posts from the watch page, and live video posts from the watch page
    # The general strategy for extracting information from each type, though, is to find which of the 30-odd GraphQL strings are relevant
    # After finding those GraphQL strings, we parse them into hashes and extract the information we need
    def extract_video_post_data(graphql_strings)
      unless all("h1").find { |h1| h1.text.strip == "Watch" }.nil?
        return extract_video_post_data_from_watch_page(graphql_strings)  # If this is a "watch page" video
      end
      graphql_object_array = graphql_strings.map { |graphql_string| JSON.parse(graphql_string) }
      sidepane_object = graphql_object_array.find { |graphql_object| graphql_object.keys.include?("tahoe_sidepane_renderer") }
      video_object = graphql_object_array.find { |graphql_object| graphql_object.keys == ["video"] }
      feedback_object = sidepane_object["tahoe_sidepane_renderer"]["video"]["feedback"]
      reaction_counts = extract_reaction_counts(feedback_object["top_reactions"])
      share_count_object = feedback_object.fetch("share_count", {})
      post_details = {
        id: video_object["id"],
        num_comments: feedback_object["comments_count_summary_renderer"]["feedback"]["comment_count"]["total_count"],
        num_shares: share_count_object.fetch("count", nil),
        num_views: feedback_object["comments_count_summary_renderer"]["feedback"]["comment_count"]["total_count"],
        reshare_warning: feedback_object["should_show_reshare_warning"],
        video_preview_image_url: video_object["video"]["preferred_thumbnail"]["image"]["uri"],
        video_url: video_object["video"]["playable_url_quality_hd"] || video_object["video"]["playable_url"],
        text: sidepane_object["tahoe_sidepane_renderer"]["video"]["creation_story"]["comet_sections"]["message"]["story"]["message"]["text"],
        created_at: video_object["video"]["publish_time"],
        profile_link: sidepane_object["tahoe_sidepane_renderer"]["video"]["creation_story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]["url"],
        has_video: true
      }
      post_details[:video_preview_image_file] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = reaction_counts
      post_details
    end

    # Extracts data from an image post by parsing GraphQL strings as seen in the video post scraper above
    def extract_image_post_data(graphql_object_array)
      viewer_actor_object = graphql_object_array.find { |graphql_object| graphql_object.keys.include?("viewer_actor") && graphql_object.keys.include?("display_comments") }
      curr_media_object = graphql_object_array.find { |graphql_object| graphql_object.keys.include?("currMedia") }
      creation_story_object = graphql_object_array.find { |graphql_object| graphql_object.keys.include?("creation_story") && graphql_object.keys.include?("message") }
      poster = creation_story_object["creation_story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]
      reaction_counts = extract_reaction_counts(viewer_actor_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["top_reactions"])
      post_details = {
        id: curr_media_object["currMedia"]["id"],
        num_comments: viewer_actor_object["comment_count"]["total_count"],
        num_shares: viewer_actor_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["share_count"]["count"],
        reshare_warning: viewer_actor_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["share_count"]["count"],
        image_url: curr_media_object["currMedia"]["image"]["uri"],
        text: (creation_story_object["message"] || {}).fetch("text", nil),
        profile_link: poster["url"],
        created_at: curr_media_object["currMedia"]["created_time"],
        has_video: false
      }
      post_details[:image_file] = Forki.retrieve_media(post_details[:image_url])
      post_details[:reactions] = reaction_counts
      post_details
    end

    # Extract data from a non-live video post on the watch page
    def extract_video_post_data_from_watch_page(graphql_strings)
      return extract_live_video_post_data_from_watch_page(graphql_strings) if current_url.include?("live")
      video_object = graphql_strings.map { |g| JSON.parse(g) }.find { |x| x.keys.include?("video") }
      creation_story_object = JSON.parse(graphql_strings.find { |graphql_string| (graphql_string.include?("creation_story")) && \
                                                            (graphql_string.include?("live_status")) } )
      video_permalink = creation_story_object["creation_story"]["shareable"]["url"].gsub("\\", "")
      media_object = video_object["video"]["story"]["attachments"][0]["media"]
      reaction_counts = extract_reaction_counts(creation_story_object["feedback"]["top_reactions"])
      post_details = {
        id: video_object["id"],
        num_comments: creation_story_object["feedback"]["comment_count"]["total_count"],
        num_shares: nil, # Not present for watch feed videos?
        num_views: creation_story_object["feedback"]["video_view_count_renderer"]["feedback"]["video_view_count"],
        reshare_warning: creation_story_object["feedback"]["should_show_reshare_warning"],
        video_preview_image_url: video_object["video"]["story"]["attachments"][0]["media"]["preferred_thumbnail"]["image"]["uri"],
        video_url: (media_object.fetch("playable_url_quality_hd", nil) || media_object.fetch("playable_url", nil)).gsub("\\", ""),
        text: (creation_story_object["creation_story"]["message"] || {})["text"],
        created_at: video_object["video"]["story"]["attachments"][0]["media"]["publish_time"],
        profile_link: video_permalink[..video_permalink.index("/videos")],
        has_video: true
      }
      post_details[:video_preview_image_file] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = reaction_counts
      post_details

    end

    # Extract data from live video post on the watch page
    def extract_live_video_post_data_from_watch_page(graphql_strings)
      creation_story_object = JSON.parse(graphql_strings.find { |graphql| (graphql.include? "comment_count") && \
                                                       (graphql.include? "creation_story") })["video"]["creation_story"]
      media_object = JSON.parse(graphql_strings.find { |graphql| graphql.include? "playable_url" } )["video"]["creation_story"]["attachments"][0]["media"]
      video_permalink = creation_story_object["shareable"]["url"].gsub("\\", "")
      reaction_counts = extract_reaction_counts(creation_story_object["feedback_context"]["feedback_target_with_context"]["top_reactions"])
      post_details = {
        id: creation_story_object["shareable"]["id"],
        num_comments: creation_story_object["feedback_context"]["feedback_target_with_context"]["comment_count"]["total_count"],
        num_shares: nil,
        num_views: find_number_of_views, # as far as I can tell, this is never present for live videos
        reshare_warning: creation_story_object["feedback_context"]["feedback_target_with_context"]["should_show_reshare_warning"],
        video_preview_image_url: creation_story_object["attachments"][0]["media"]["preferred_thumbnail"]["image"]["uri"],
        video_url: (media_object.fetch("playable_url_quality_hd", nil) || media_object.fetch("playable_url", nil)).gsub("\\", ""),
        text: creation_story_object["attachments"][0]["media"]["savable_description"]["text"],
        created_at: creation_story_object["attachments"][0]["media"]["publish_time"],
        profile_link: video_permalink[..video_permalink.index("/videos")],
        has_video: true
      }
      post_details[:video_preview_image_file] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = reaction_counts
      post_details
    end

    # Returns a hash containing counts of each reaction to a post
    # Takes the edges list and creates a dictionary for each element that looks like: {:num_likes: 1234}
    # Then merges the dictionaries with the inject call
    def extract_reaction_counts(reactions_object)
      reactions_object["edges"].map do |reaction|
        {
          "num_#{reaction["node"]["localized_name"].downcase}s".to_sym => reaction["reaction_count"]
        }
      end.inject { |emoji_counts, count| emoji_counts.merge(count) }
    end

    # Uses GraphQL data and DOM elements to collect information about the current post
    def parse(url)
      validate_and_load_page(url)
      graphql_strings = find_graphql_data_strings(page.html)
      post_data = extract_post_data(graphql_strings)

      user_url = post_data[:profile_link]
      post_data[:url] = url
      post_data[:user] = User.lookup(user_url).first
      post_data
    end
  end
end
