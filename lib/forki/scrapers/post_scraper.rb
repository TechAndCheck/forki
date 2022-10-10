# frozen_string_literal: true

require "typhoeus"
require "securerandom"

module Forki
  # rubocop:disable Metrics/ClassLength
  class PostScraper < Scraper
    # Searches the DOM to finds the number of times a (video) post has been viewed.
    # Returns nil if it can't find a DOM element with the view count

    def find_number_of_views
      views_pattern = /[0-9MK, ]+Views/
      spans = all("span")
      views_span = spans.find { |s| s.text(:all) =~ views_pattern }
      extract_int_from_num_element(views_span)
    end

    def extract_post_data(graphql_strings)
      # Bail out of the post otherwise it gets stuck
      raise ContentUnavailableError unless is_post_available?

      graphql_objects = get_graphql_objects(graphql_strings)
      post_has_video = check_if_post_is_video(graphql_objects)
      post_has_image = check_if_post_is_image(graphql_objects)

      # There's a chance it may be embedded in a comment chain like this:
      # https://www.facebook.com/PlandemicMovie/posts/588866298398729/
      post_has_video_in_comment_stream = check_if_post_is_in_comment_stream(graphql_objects) if post_has_video == false

      if post_has_video
        extract_video_post_data(graphql_strings)
      elsif post_has_video_in_comment_stream
        extract_video_comment_post_data(graphql_objects)
      elsif post_has_image
        extract_image_post_data(graphql_objects)
      else
        raise UnhandledContentError
      end
    end

    def get_graphql_objects(graphql_strings)
      graphql_strings.map { |graphql_object| JSON.parse(graphql_object) }
    end

    def check_if_post_is_video(graphql_objects)
      graphql_objects.any? { |graphql_object| graphql_object.key?("is_live_streaming") | graphql_object.key?("video") }
    end

    def check_if_post_is_image(graphql_objects)
      graphql_objects.any? do |graphql_object|  # if any GraphQL objects contain the top-level keys above, return true
        true unless graphql_object.fetch("image", nil).nil? # so long as the associated values are not nil
        true unless graphql_object.fetch("currMedia", nil).nil?
      end
    end

    def check_if_post_is_in_comment_stream(graphql_objects)
      graphql_objects.find do |graphql_object|
        next unless graphql_object.key?("nodes")

        begin
          type = graphql_object["nodes"].first["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["media"]["__typename"]
        rescue StandardError
          # if there's an error just return false, since the structure is so specific checking the whole thing is a lot
          next
        end

        return true if type == "Video"
      end

      false
    end

    def is_post_available?
      begin
        find("span", wait: 5, text: "content isn't available", exact_text: false)
      rescue Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
        return true
      end

      false
    end

    def extract_video_comment_post_data(graphql_objects)
      graphql_nodes = nil
      graphql_objects.find do |graphql_object|
        next unless graphql_object.key?("nodes")

        graphql_nodes = graphql_object["nodes"]
        break
      end

      media = graphql_nodes.first["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["media"]
      inital_feedback_object = graphql_nodes.first["comet_sections"]["feedback"]["story"]["feedback_context"]["feedback_target_with_context"]["ufi_renderer"]["feedback"]
      feedback_object = inital_feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]

      post_details = {
        id: media["id"],
        num_comments: feedback_object["comment_count"]["total_count"],
        num_shares: feedback_object["share_count"]["count"],
        num_views: feedback_object["video_view_count"],
        reshare_warning: feedback_object["should_show_reshare_warning"],
        video_preview_image_url: media["preferred_thumbnail"]["image"]["uri"],
        video_url: media["playable_url_quality_hd"] || media["playable_url"],
        text: graphql_nodes.first["comet_sections"]["content"]["story"]["comet_sections"]["message"]["story"]["message"]["text"],
        created_at: media["publish_time"],
        profile_link: graphql_nodes.first["comet_sections"]["context_layout"]["story"]["comet_sections"]["actor_photo"]["story"]["actors"].first["url"],
        has_video: true
      }
      post_details[:video_preview_image_file] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = inital_feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["i18n_reaction_count"]
      post_details
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
      story_node_object = graphql_object_array.find { |graphql_object| graphql_object.key? "node" }&.fetch("node", nil) # user posted video
      story_node_object = story_node_object || graphql_object_array.find { |graphql_object| graphql_object.key? "nodes" }&.fetch("nodes")&.first # page posted video

      return extract_video_post_data_alternative(graphql_object_array) if story_node_object.nil?

      if story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"].key?("media")
        video_object = story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["media"]
        creation_date = video_object["publish_time"]
        # creation_date = video_object["video"]["publish_time"]
      elsif story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"].key?("style_infos")
        # For "Reels" we need a separate way to parse this
        video_object = story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["style_infos"].first["fb_shorts_story"]["short_form_video_context"]["playback_video"]
        creation_date = story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["style_infos"].first["fb_shorts_story"]["creation_time"]
      else
        raise "Unable to parse video object"
      end

      feedback_object = story_node_object["comet_sections"]["feedback"]["story"]["feedback_context"]["feedback_target_with_context"]["ufi_renderer"]["feedback"]
      reaction_counts = extract_reaction_counts(feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["cannot_see_top_custom_reactions"]["top_reactions"])
      share_count_object = feedback_object.fetch("share_count", {})

      if story_node_object["comet_sections"]["content"]["story"]["comet_sections"].key? "message"
        text = story_node_object["comet_sections"]["content"]["story"]["comet_sections"]["message"]["story"]["message"]["text"]
      else
        text = ""
      end

      # debugger
      post_details = {
        id: video_object["id"],
        num_comments: feedback_object["comment_count"]["total_count"],
        num_shares: share_count_object.fetch("count", nil),
        num_views: feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["video_view_count"],
        reshare_warning: feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["should_show_reshare_warning"],
        video_preview_image_url: video_object["preferred_thumbnail"]["image"]["uri"],
        video_url: video_object["playable_url_quality_hd"] || video_object["playable_url"],
        text: text,
        created_at: creation_date,
        profile_link: story_node_object["comet_sections"]["context_layout"]["story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]["url"],
        has_video: true
      }
      post_details[:video_preview_image_file] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = reaction_counts
      post_details
    end

    def extract_video_post_data_alternative(graphql_object_array)
      sidepane_object = graphql_object_array.find { |graphql_object| graphql_object.key?("tahoe_sidepane_renderer") }
      video_object = graphql_object_array.find { |graphql_object| graphql_object.keys == ["video"] }
      feedback_object = sidepane_object["tahoe_sidepane_renderer"]["video"]["feedback"]
      reaction_counts = extract_reaction_counts(sidepane_object["tahoe_sidepane_renderer"]["video"]["feedback"]["cannot_see_top_custom_reactions"]["top_reactions"])
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
      viewer_actor_object = graphql_object_array.find { |graphql_object| graphql_object.key?("viewer_actor") && graphql_object.key?("display_comments") }
      curr_media_object = graphql_object_array.find { |graphql_object| graphql_object.key?("currMedia") }
      creation_story_object = graphql_object_array.find { |graphql_object| graphql_object.key?("creation_story") && graphql_object.key?("message") }

      poster = creation_story_object["creation_story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]

      reaction_counts = extract_reaction_counts(viewer_actor_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["cannot_see_top_custom_reactions"]["top_reactions"])
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
      video_object = graphql_strings.map { |g| JSON.parse(g) }.find { |x| x.key?("video") }
      creation_story_object = JSON.parse(graphql_strings.find { |graphql_string| (graphql_string.include?("creation_story")) && \
                                                            (graphql_string.include?("live_status")) })
      video_permalink = creation_story_object["creation_story"]["shareable"]["url"].delete("\\")
      media_object = video_object["video"]["story"]["attachments"][0]["media"]
      reaction_counts = extract_reaction_counts(creation_story_object["feedback"]["cannot_see_top_custom_reactions"]["top_reactions"])
      post_details = {
        id: video_object["id"],
        num_comments: creation_story_object["feedback"]["comment_count"]["total_count"],
        num_shares: nil, # Not present for watch feed videos?
        num_views: creation_story_object["feedback"]["video_view_count_renderer"]["feedback"]["video_view_count"],
        reshare_warning: creation_story_object["feedback"]["should_show_reshare_warning"],
        video_preview_image_url: video_object["video"]["story"]["attachments"][0]["media"]["preferred_thumbnail"]["image"]["uri"],
        video_url: (media_object.fetch("playable_url_quality_hd", nil) || media_object.fetch("playable_url", nil)).delete("\\"),
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
      media_object = JSON.parse(graphql_strings.find { |graphql| graphql.include? "playable_url" })["video"]["creation_story"]["attachments"][0]["media"]
      video_permalink = creation_story_object["shareable"]["url"].delete("\\")
      reaction_counts = extract_reaction_counts(creation_story_object["feedback_context"]["feedback_target_with_context"]["cannot_see_top_custom_reactions"]["top_reactions"])
      post_details = {
        id: creation_story_object["shareable"]["id"],
        num_comments: creation_story_object["feedback_context"]["feedback_target_with_context"]["comment_count"]["total_count"],
        num_shares: nil,
        num_views: find_number_of_views, # as far as I can tell, this is never present for live videos
        reshare_warning: creation_story_object["feedback_context"]["feedback_target_with_context"]["should_show_reshare_warning"],
        video_preview_image_url: creation_story_object["attachments"][0]["media"]["preferred_thumbnail"]["image"]["uri"],
        video_url: (media_object.fetch("playable_url_quality_hd", nil) || media_object.fetch("playable_url", nil)).delete("\\"),
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
      post_data[:url] = url
      user_url = post_data[:profile_link]

      5.times do
        begin
          post_data[:screenshot_file] = save_screenshot("#{Forki.temp_storage_location}/facebook_screenshot_#{SecureRandom.uuid}.png")
          break
        rescue Net::ReadTimeout; end

        sleep(5)
      end

      page.quit # Close browser between page navigations to prevent cache folder access issues

      post_data[:user] = User.lookup(user_url).first
      page.quit

      post_data
    rescue StandardError => e
      raise e
    ensure
      page.quit
    end
  end
end
