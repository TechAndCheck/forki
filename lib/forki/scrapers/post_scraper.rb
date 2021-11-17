# frozen_string_literal: true

require "typhoeus"

module Forki
  class PostScraper < Scraper

    # Searches the DOM to finds the number of times a (video) post has been viewed.
    # Returns nil if it can't find a DOM element with the view count
    def find_num_views
      views_pattern = /[0-9MK, ]+Views/
      spans = all("span")
      views_span = spans.find { | s| s.text(:all) =~ views_pattern}
      extract_int_from_num_element(views_span)
    end

    def extract_post_data(gql_strings)
      gql_objects = gql_strings.map { |gql_obj| JSON.parse(gql_obj) }
      post_has_video = gql_objects.any? { |gql_object| gql_object.keys.include?("video") }
      post_has_video ? extract_vid_post_data(gql_strings) : extract_img_post_data(gql_objects)
    end

    # Unfortunately, there's a taxonomy of video post types, all of which require different parsing methods
    # Specifically, there are normal video posts, video posts from the watch page, and live video posts from the watch page
    # The general strategy for extracting information from each type, though, is to find which of the 30-odd GraphQL strings are relevant
    # After finding those GraphQL strings, we parse them into hashes and extract the information we need
    def extract_vid_post_data(gql_strs)
      unless all("h1").find { |h1| h1.text.strip == "Watch" }.nil?
        return extract_vid_post_data_from_watch_page(gql_strs)  # If this is a "watch page" video
      end
      gql_obj_array = gql_strs.map { |gql_str| JSON.parse(gql_str) }
      feedback_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("creation_story") && \
                                                       gql_object.keys.include?("feedback")}
      sidepane_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("tahoe_sidepane_renderer") }
      video_obj = gql_obj_array.find { |gql_object| gql_object.keys == ["video"] }

      reaction_counts = extract_reaction_counts(feedback_obj["feedback"]["top_reactions"])
      share_count_obj = feedback_obj["feedback"].fetch("share_count", {})
      post_details = {
        id: video_obj["id"],
        num_comments: feedback_obj["feedback"]["comment_count"]["total_count"],
        num_shares: share_count_obj.fetch("count", nil),
        num_views: feedback_obj["feedback"]["video_view_count_renderer"]["feedback"]["video_view_count"],
        reshare_warning: feedback_obj["feedback"]["should_show_reshare_warning"],
        video_preview_image_url: video_obj["video"]["preferred_thumbnail"]["image"]["uri"],
        video_url: video_obj["video"]["playable_url_quality_hd"] || video_obj["video"]["playable_url"],
        text: sidepane_obj["tahoe_sidepane_renderer"]["video"]["creation_story"]["comet_sections"]["message"]["story"]["message"]["text"],
        created_at: video_obj["video"]["publish_time"],
        profile_link: sidepane_obj["tahoe_sidepane_renderer"]["video"]["creation_story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]["url"],
        has_video: true
      }
      post_details[:video_preview_image_file] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = reaction_counts
      post_details
    end

    # Extracts data from an image post by parsing GraphQL strings as seen in the video post scraper above
    def extract_img_post_data(gql_obj_array)
      viewer_actor_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("viewer_actor") && gql_object.keys.include?("display_comments") }
      cur_media_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("currMedia") }
      creation_story_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("creation_story") && gql_object.keys.include?("message") }
      poster = creation_story_obj["creation_story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]
      reaction_counts = extract_reaction_counts(viewer_actor_obj["comet_ufi_summary_and_actions_renderer"]["feedback"]["top_reactions"])
      post_details = {
        id: cur_media_obj["currMedia"]["id"],
        num_comments: viewer_actor_obj["comment_count"]["total_count"],
        num_shares: viewer_actor_obj["comet_ufi_summary_and_actions_renderer"]["feedback"]["share_count"]["count"],
        reshare_warning: viewer_actor_obj["comet_ufi_summary_and_actions_renderer"]["feedback"]["share_count"]["count"],
        image_url: cur_media_obj["currMedia"]["image"]["uri"],
        text: (creation_story_obj["message"] || {}).fetch("text", nil),
        profile_link: poster["url"],
        created_at: cur_media_obj["currMedia"]["created_time"],
        has_video: false
      }
      post_details[:image_file] = Forki.retrieve_media(post_details[:image_url])
      post_details[:reactions] = reaction_counts
      post_details
    end

    # Extract data from a non-live video post on the watch page
    def extract_vid_post_data_from_watch_page(gql_strs)
      return extract_live_video_post_data_from_watch_page(gql_strs) if current_url.include?("live")
      video_obj = gql_strs.map { |g| JSON.parse(g) }.find { |x| x.keys.include?("video") }
      creation_story_obj = JSON.parse(gql_strs.find { |gql| (gql.include?("creation_story")) && \
                                                            (gql.include?("live_status")) } )
      video_permalink = creation_story_obj["creation_story"]["shareable"]["url"].gsub("\\", "")
      media_object = video_obj["video"]["story"]["attachments"][0]["media"]
      reaction_counts = extract_reaction_counts(creation_story_obj["feedback"]["top_reactions"])
      post_details = {
        id: video_obj["id"],
        num_comments: creation_story_obj["feedback"]["comment_count"]["total_count"],
        num_shares: nil, # Not present for watch feed videos?
        num_views: creation_story_obj["feedback"]["video_view_count_renderer"]["feedback"]["video_view_count"],
        reshare_warning: creation_story_obj["feedback"]["should_show_reshare_warning"],
        video_preview_image_url: video_obj["video"]["story"]["attachments"][0]["media"]["preferred_thumbnail"]["image"]["uri"],
        video_url: (media_object.fetch("playable_url_quality_hd", nil) || media_object.fetch("playable_url", nil)).gsub("\\", ""),
        text: (creation_story_obj["creation_story"]["message"] || {})["text"],
        created_at: video_obj["video"]["story"]["attachments"][0]["media"]["publish_time"],
        profile_link: video_permalink[..video_permalink.index("/videos")],
        has_video: true
      }
      post_details[:video_preview_image_file] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = reaction_counts
      post_details

    end

    # Extract data from live video post on the watch page
    def extract_live_video_post_data_from_watch_page(gql_strs)
      creation_story_obj = JSON.parse(gql_strs.find { |gql| (gql.include? "comment_count") && \
                                                       (gql.include? "creation_story") })["video"]["creation_story"]
      media_object = JSON.parse(gql_strs.find { |gql| gql.include? "playable_url" } )["video"]["creation_story"]["attachments"][0]["media"]
      video_permalink = creation_story_obj["shareable"]["url"].gsub("\\", "")
      reaction_counts = extract_reaction_counts(creation_story_obj["feedback_context"]["feedback_target_with_context"]["top_reactions"])
      post_details = {
        id: creation_story_obj["shareable"]["id"],
        num_comments: creation_story_obj["feedback_context"]["feedback_target_with_context"]["comment_count"]["total_count"],
        num_shares: nil,
        num_views: find_num_views, # as far as I can tell, this is never present for live videos
        reshare_warning: creation_story_obj["feedback_context"]["feedback_target_with_context"]["should_show_reshare_warning"],
        video_preview_image_url: creation_story_obj["attachments"][0]["media"]["preferred_thumbnail"]["image"]["uri"],
        video_url: (media_object.fetch("playable_url_quality_hd", nil) || media_object.fetch("playable_url", nil)).gsub("\\", ""),
        text: creation_story_obj["attachments"][0]["media"]["savable_description"]["text"],
        created_at: creation_story_obj["attachments"][0]["media"]["publish_time"],
        profile_link: video_permalink[..video_permalink.index("/videos")],
        has_video: true
      }
      post_details[:video_preview_image_file] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = reaction_counts
      post_details
    end

    def extract_reaction_counts(reactions_obj)
      reactions_obj["edges"].map do |reaction|
        {
          "num_#{reaction["node"]["localized_name"].downcase}s".to_sym => reaction["reaction_count"]
        }
      end.inject { |emoji_counts, count| emoji_counts.merge(count) }
    end

    def parse(url)
      # Stuff we need to get from the DOM (implemented is starred):
      # - User *
      # - Text *
      # - Image/Video *
      # - Multiple images
      # - Creation date *
      # - Reaction tallies *
      # - Number of views, comments, and shares *

      validate_and_load_page(url)
      gql_strs = find_graphql_data_strings(page.html)
      post_data = extract_post_data(gql_strs)

      user_url = post_data[:profile_link]
      post_data[:url] = url
      post_data[:user] = User.lookup(user_url).first
      post_data
    end
  end
end
