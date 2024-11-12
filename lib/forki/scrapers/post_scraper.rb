# frozen_string_literal: true

require "typhoeus"
require "securerandom"
require "byebug"


module Forki
  # rubocop:disable Metrics/ClassLength
  class PostScraper < Scraper
    # Searches the DOM to finds the number of times a (video) post has been viewed.
    # Returns nil if it can't find a DOM element with the view count

    def find_number_of_views
      views_pattern = /[0-9MK, ]+Views/
      spans = all("span")
      views_span = spans.find { |s| s.text(:all) =~ views_pattern }
      Scraper.extract_int_from_num_element(views_span)
    end

    def extract_post_data(graphql_strings)
      # Bail out of the post otherwise it gets stuck
      raise ContentUnavailableError unless is_post_available?

      graphql_objects = get_graphql_objects(graphql_strings)
      post_is_text_only = check_if_post_is_text_only(graphql_objects)
      post_has_video = check_if_post_is_video(graphql_objects)
      post_has_image = check_if_post_is_image(graphql_objects)

      # There's a chance it may be embedded in a comment chain like this:
      # https://www.facebook.com/PlandemicMovie/posts/588866298398729/
      post_has_video_in_comment_stream = check_if_post_is_in_comment_stream(graphql_objects) if post_has_video == false


      if post_is_text_only
        extract_text_post_data(graphql_objects)
      elsif post_has_image && !post_has_video && !post_has_video_in_comment_stream
        extract_image_post_data(graphql_objects)
      elsif post_has_video
        extract_video_post_data(graphql_strings)
      elsif post_has_video_in_comment_stream
        extract_video_comment_post_data(graphql_objects)
      else
        extract_image_post_data(graphql_objects)
      end
    end

    def get_graphql_objects(graphql_strings)
      graphql_strings.map { |graphql_object| JSON.parse(graphql_object) }
    end

    def check_if_post_is_text_only(graphql_objects)
      graphql_object = graphql_objects.find do |graphql_object|
        # next unless graphql_object.key?("nodes")
        next if graphql_object.dig("node", "comet_sections", "content", "story", "comet_sections", "message", "story", "is_text_only_story").nil?
        # next unless graphql_object.to_s.include?("is_text_only_story")
        # graphql_nodes = graphql_object["nodes"]
        graphql_object.dig("node", "comet_sections", "content", "story", "comet_sections", "message", "story", "is_text_only_story")
      end

      return false if graphql_object.nil?

      return true if graphql_object.dig("node", "comet_sections", "content", "story", "comet_sections", "message", "story", "is_text_only_story")
      false
    end

    def check_if_post_is_video(graphql_objects)
      result = graphql_objects.find do |graphql_object|
        next unless graphql_object.dig("viewer", "news_feed").nil? # The new page loads the news feed *and* the post
        next unless graphql_object.dig("node", "sponsored_data").nil? # Ads sneak in too but don't mark as feed

        result = graphql_object.to_s.include?("videoDeliveryLegacyFields")
        result = graphql_object.key?("is_live_streaming") && graphql_object["is_live_streaming"] == true if result == false
        result = graphql_object.key?("video") if result == false
        result = check_if_post_is_reel(graphql_object) if result == false
        result
      end

      !result.nil?
    end

    def check_if_post_is_reel(graphql_object)
      return false unless graphql_object.key?("node")

      begin
        style_infos = graphql_object["node"]["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["style_infos"].first
      rescue NoMethodError # if the object doesn't match the attribute chain above, the line above will try to operate on nil
        return false
      end

      style_infos.include?("fb_shorts_story")
    end

    def check_if_post_is_image(graphql_objects)
      graphql_objects.any? do |graphql_object|  # if any GraphQL objects contain the top-level keys above, return true
        return true unless graphql_object.fetch("image", nil).nil? # so long as the associated values are not nil
        return true unless graphql_object.fetch("currMedia", nil).nil?
        return true unless graphql_object.fetch("photo_image", nil).nil?
        return true unless graphql_object.fetch("large_share_image", nil).nil?

        # This is a complicated form for `web.facebook.com` posts
        if !graphql_object.dig("node", "comet_sections", "content", "story", "attachments").nil?
          if graphql_object["node"]["comet_sections"]["content"]["story"]["attachments"].count.positive?
            return true unless graphql_object["node"]["comet_sections"]["content"]["story"]["attachments"].first.dig("styles", "attachment", "all_subattachments", "nodes")&.first&.dig("media", "image", "uri").nil?

            # Another version I guess
            return true unless graphql_object["node"]["comet_sections"]["content"]["story"]["attachments"].first.dig("styles", "attachment", "media", "large_share_image")&.dig("uri").nil?
          end
        end

        # Another weird format
        begin
          if !graphql_object["node"]["comet_sections"]["content"]["story"]["attachments"].empty?
            return true unless graphql_object["node"]["comet_sections"]["content"]["story"]["attachments"].first.dig("styles", "attachment", "media", "photo_image", "uri").nil?
          end
        rescue StandardError

        end
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
        # This Video Isn't Available Anymore
        find("span", wait: 5, text: "content isn't available", exact_text: false)
      rescue Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
        begin
          find("span", wait: 5, text: "This Video Isn't Available Anymore", exact_text: false)
        rescue Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
          begin
            find("span", wait: 5, text: "This Page Isn't Available", exact_text: false)
          rescue Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
            return true
          end
        end
      end

      false
    end

    def extract_text_post_data(graphql_objects)
      graphql_object = graphql_objects.find do |graphql_object|
        next if graphql_object.dig("node", "comet_sections", "content", "story", "comet_sections", "message", "story", "is_text_only_story").nil?
        graphql_object
      end

      unless graphql_object.nil? || graphql_object.count.zero?
        if graphql_object["node"]["comet_sections"]["feedback"]["story"].has_key?("story_ufi_container")
          feedback_object = graphql_object["node"]["comet_sections"]["feedback"]["story"]["story_ufi_container"]["story"]["feedback_context"]["feedback_target_with_context"]["comet_ufi_summary_and_actions_renderer"]["feedback"]
        elsif graphql_object["node"]["comet_sections"]["feedback"]["story"].dig("feedback_context")
          begin
            feedback_object = graphql_object["node"]["comet_sections"]["feedback"]["story"]["feedback_context"]["feedback_target_with_context"]["ufi_renderer"]["feedback"]["comet_ufi_summary_and_actions_renderer"]["feedback"]
          rescue NoMethodError; end
        elsif graphql_object["node"]["comet_sections"]["feedback"]["story"].has_key?("comet_feed_ufi_container")
          feedback_object = graphql_object["node"]["comet_sections"]["feedback"]["story"]["comet_feed_ufi_container"]["story"]["story_ufi_container"]["story"]["feedback_context"]["feedback_target_with_context"]["comet_ufi_summary_and_actions_renderer"]["feedback"]
        else
          feedback_object = graphql_object["node"]["comet_sections"]["feedback"]["story"]["feedback_context"]["feedback_target_with_context"]["ufi_renderer"]["feedback"]["comet_ufi_summary_and_actions_renderer"]["feedback"]
        end

        if feedback_object.has_key?("cannot_see_top_custom_reactions")
          reaction_counts = extract_reaction_counts(feedback_object["cannot_see_top_custom_reactions"]["top_reactions"])
        else
          reaction_counts = extract_reaction_counts(feedback_object["top_reactions"])
        end

        id = graphql_object["node"]["post_id"]
        num_comments = feedback_object["comments_count_summary_renderer"]["feedback"]["comment_rendering_instance"]["comments"]["total_count"]
        reshare_warning = feedback_object["should_show_reshare_warning"]
        share_count_object = feedback_object.fetch("share_count", {})
        num_shares = share_count_object.fetch("count", nil)

        text = graphql_object["node"]["comet_sections"]["content"]["story"].dig("message", "text")
        text = "" if text.nil?

        profile_link = graphql_object["node"]["comet_sections"]["content"]["story"]["actors"].first["url"]

        unless graphql_object["node"]["comet_sections"].dig("content", "story", "comet_sections", "context_layout", "story", "comet_sections", "metadata").nil?
          created_at = graphql_object["node"]["comet_sections"].dig("content", "story", "comet_sections", "context_layout", "story", "comet_sections", "metadata")&.first["story"]["creation_time"]
        else
          created_at = graphql_object["node"]["comet_sections"]["context_layout"]["story"]["comet_sections"]["metadata"].first["story"]["creation_time"]
        end

        has_video = false
      end

      post_details = {
        id: id,
        num_comments: num_comments,
        num_shares: num_shares,
        reshare_warning: reshare_warning,
        image_url: nil,
        text: text,
        profile_link: profile_link,
        created_at: created_at,
        has_video: has_video
      }
      post_details[:image_file] = []
      post_details[:reactions] = reaction_counts
      post_details
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

      # Once in awhile it's really easy
      video_objects = graphql_object_array.filter { |go| go.has_key?("video") }

      if VideoSieve.can_process_with_sieve?(graphql_object_array)
        # Eventually all of this complexity will be replaced with this
        return VideoSieve.sieve_for_graphql_objects(graphql_object_array)
      end

      story_node_object = graphql_object_array.find { |graphql_object| graphql_object.key? "node" }&.fetch("node", nil) # user posted video
      story_node_object = story_node_object || graphql_object_array.find { |graphql_object| graphql_object.key? "nodes" }&.fetch("nodes")&.first # page posted video

      return extract_video_post_data_alternative(graphql_object_array) if story_node_object.nil?

      if story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"].key?("media")
        media_object = story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]
        if media_object.has_key?("video")
          video_object = story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["media"]["video"]
        elsif media_object.has_key?("media") && (media_object["media"].has_key?("browser_native_sd_url") || media_object["media"].has_key?("videoDeliveryLegacyFields"))
          video_object = media_object["media"]
        end

        creation_date = video_object["publish_time"] if video_object&.has_key?("publish_time")
        creation_date = story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["media"]["publish_time"] if creation_date.nil?
      elsif story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"].key?("style_infos")
        # For "Reels" we need a separate way to parse this
        video_object = story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["style_infos"].first["fb_shorts_story"]["short_form_video_context"]["playback_video"]
        creation_date = story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["style_infos"].first["fb_shorts_story"]["creation_time"]
      else
        raise "Unable to parse video object" if video_objects.empty?
      end

      begin
        feedback_object = story_node_object["comet_sections"]["feedback"]["story"]["feedback_context"]["feedback_target_with_context"]["ufi_renderer"]["feedback"]
      rescue NoMethodError
        begin
          feedback_object = story_node_object["comet_sections"]["feedback"]["story"]["comet_feed_ufi_container"]["story"]["story_ufi_container"]["story"]["feedback_context"]["feedback_target_with_context"]
        rescue NoMethodError
          feedback_object = story_node_object["comet_sections"]["feedback"]["story"]["story_ufi_container"]["story"]["feedback_context"]["feedback_target_with_context"]
        end
      end

      if feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"].key?("cannot_see_top_custom_reactions")
        reaction_counts = extract_reaction_counts(feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["cannot_see_top_custom_reactions"]["top_reactions"])
      else
        reaction_counts = extract_reaction_counts(feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["top_reactions"])
      end

      feedback_object = feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]

      share_count_object = feedback_object.fetch("share_count", {})

      if story_node_object["comet_sections"]["content"]["story"]["comet_sections"].key?("message") && !story_node_object["comet_sections"]["content"]["story"]["comet_sections"]["message"].nil?
        text = story_node_object["comet_sections"]["content"]["story"]["comet_sections"]["message"]["story"]["message"]["text"]
      else
        text = ""
      end

      if feedback_object.has_key?("comment_list_renderer")
        if feedback_object["comment_list_renderer"]["feedback"].key?("comment_count")
          num_comments = feedback_object["comment_list_renderer"]["feedback"]["comment_count"]["total_count"]
        else
          num_comments = feedback_object["comment_list_renderer"]["feedback"]["total_comment_count"]
        end

        view_count = feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["video_view_count"]
        reshare_warning = feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["should_show_reshare_warning"]
      elsif feedback_object.has_key?("comments_count_summary_renderer")
        num_comments = feedback_object["comments_count_summary_renderer"]["feedback"]["comment_rendering_instance"]["comments"]["total_count"]

        view_count = feedback_object["video_view_count"]
        reshare_warning = feedback_object["should_show_reshare_warning"]
      else
        if feedback_object["feedback"].key?("comment_count")
          num_comments = feedback_object["feedback"]["comment_count"]["total_count"]
        else
          num_comments = feedback_object["feedback"]["total_comment_count"]
        end

        view_count = feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["video_view_count"]
        reshare_warning = feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["should_show_reshare_warning"]
      end

      if video_object.has_key?("videoDeliveryResponseFragment") && !video_object["videoDeliveryResponseFragment"].nil?
        progressive_urls_wrapper = video_object["videoDeliveryResponseFragment"]["videoDeliveryResponseResult"]
        video_url = progressive_urls_wrapper["progressive_urls"].find_all { |object| !object["progressive_url"].nil? }.last["progressive_url"]
      else
        video_object_url_subsearch = video_object
        video_object_url_subsearch = video_object_url_subsearch["videoDeliveryLegacyFields"] if video_object_url_subsearch.has_key?("videoDeliveryLegacyFields")
        video_url = video_object_url_subsearch["browser_native_hd_url"] || video_object_url_subsearch["browser_native_sd_url"]
      end

      video_url = "" if video_url.nil?

      post_details = {
        id: video_object["id"],
        num_comments: num_comments,
        num_shares: share_count_object.fetch("count", nil),
        num_views: view_count,
        reshare_warning: reshare_warning,
        video_preview_image_url: video_object["preferred_thumbnail"]["image"]["uri"],
        video_url: video_url,
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
      video_object = graphql_object_array.find { |graphql_object| graphql_object.has_key?("video") }

      raise Forki::ContentUnavailableError if sidepane_object.nil? && video_object.nil?

      feedback_object = sidepane_object["tahoe_sidepane_renderer"]["video"]["feedback"]

      if sidepane_object["tahoe_sidepane_renderer"]["video"]["feedback"].key?("cannot_see_top_custom_reactions")
        reaction_counts = extract_reaction_counts(sidepane_object["tahoe_sidepane_renderer"]["video"]["feedback"]["cannot_see_top_custom_reactions"]["top_reactions"])
      else # if the video has no reactions, it will have a different structure
        reaction_counts = extract_reaction_counts(sidepane_object["tahoe_sidepane_renderer"]["video"]["feedback"]["top_reactions"])
      end

      share_count_object = feedback_object.fetch("share_count", {})

      if feedback_object["comments_count_summary_renderer"]["feedback"].has_key?("comment_rendering_instance")
        num_comments = feedback_object["comments_count_summary_renderer"]["feedback"]["comment_rendering_instance"]["comments"]["total_count"]
      else
        num_comments = feedback_object["comments_count_summary_renderer"]["feedback"]["total_comment_count"]
      end

      text = sidepane_object["tahoe_sidepane_renderer"]["video"]["creation_story"]["comet_sections"].dig("message", "story", "message", "text")
      text = "" if text.nil?

      video_url = video_object["video"]["playable_url_quality_hd"] || video_object["video"]["browser_native_hd_url"] || video_object["video"]["browser_native_sd_url"] || video_object["video"]["playable_url"]
      if video_url.nil? && !video_object.dig("video", "videoDeliveryLegacyFields").nil?
        video_url = video_object["video"]["videoDeliveryLegacyFields"]["browser_native_hd_url"] || video_object["video"]["videoDeliveryLegacyFields"]["browser_native_sd_url"]
      elsif !video_object.dig("video", "videoDeliveryResponseFragment", "videoDeliveryResponseResult").nil?
        progressive_urls_wrapper = video_object["video"]["videoDeliveryResponseFragment"]["videoDeliveryResponseResult"]
        video_url = progressive_urls_wrapper["progressive_urls"].find_all { |object| !object["progressive_url"].nil? }.last["progressive_url"]
      end

      post_details = {
        id: video_object["id"],
        num_comments: num_comments,
        num_shares: share_count_object.fetch("count", nil),
        num_views: feedback_object["video_view_count"],
        reshare_warning: feedback_object["should_show_reshare_warning"],
        video_preview_image_url: video_object["video"]["preferred_thumbnail"]["image"]["uri"],
        video_url: video_url,
        text: text,
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
      # This is a weird one-off style
      graphql_object = graphql_object_array.find { |graphql_object| !graphql_object.dig("node", "comet_sections", "content", "story", "attachments").nil? }
      unless graphql_object.nil? || graphql_object.count.zero?
        # TODO: These two branches are *super* similar, probably a lot of overlap
        attachments = graphql_object["node"]["comet_sections"]["content"]["story"]["attachments"]

        if graphql_object["node"]["comet_sections"]["feedback"]["story"].has_key?("story_ufi_container")
          feedback_object = graphql_object["node"]["comet_sections"]["feedback"]["story"]["story_ufi_container"]["story"]["feedback_context"]["feedback_target_with_context"]["comet_ufi_summary_and_actions_renderer"]["feedback"]
        elsif graphql_object["node"]["comet_sections"]["feedback"]["story"].dig("feedback_context")
          begin
            feedback_object = graphql_object["node"]["comet_sections"]["feedback"]["story"]["feedback_context"]["feedback_target_with_context"]["ufi_renderer"]["feedback"]["comet_ufi_summary_and_actions_renderer"]["feedback"]
          rescue NoMethodError; end
        elsif graphql_object["node"]["comet_sections"]["feedback"]["story"].has_key?("comet_feed_ufi_container")
          feedback_object = graphql_object["node"]["comet_sections"]["feedback"]["story"]["comet_feed_ufi_container"]["story"]["story_ufi_container"]["story"]["feedback_context"]["feedback_target_with_context"]["comet_ufi_summary_and_actions_renderer"]["feedback"]
        else
          feedback_object = graphql_object["node"]["comet_sections"]["feedback"]["story"]["feedback_context"]["feedback_target_with_context"]["ufi_renderer"]["feedback"]["comet_ufi_summary_and_actions_renderer"]["feedback"]
        end

        if feedback_object.has_key?("cannot_see_top_custom_reactions")
          reaction_counts = extract_reaction_counts(feedback_object["cannot_see_top_custom_reactions"]["top_reactions"])
        else
          reaction_counts = extract_reaction_counts(feedback_object["top_reactions"])
        end

        id = graphql_object["node"]["post_id"]
        num_comments = feedback_object["comments_count_summary_renderer"]["feedback"]["comment_rendering_instance"]["comments"]["total_count"]
        reshare_warning = feedback_object["should_show_reshare_warning"]

        if attachments.count.positive? && attachments.first["styles"]["attachment"]&.key?("all_subattachments")
          image_url = attachments.first["styles"]["attachment"]["all_subattachments"]["nodes"].first["media"]["image"]["uri"]
        else
          image_url = attachments.first&.dig("styles", "attachment", "media", "photo_image", "uri")

          if image_url.nil?
            image_url = attachments.first&.dig("styles", "attachment", "media", "large_share_image", "uri")
          end

          if image_url.nil?
            image_url = attachments.first&.dig("styles", "attachment", "media", "image", "uri")
          end
        end

        text = graphql_object["node"]["comet_sections"]["content"]["story"].dig("message", "text")
        text = "" if text.nil?

        profile_link = graphql_object["node"]["comet_sections"]["content"]["story"]["actors"].first["url"]

        unless graphql_object["node"]["comet_sections"].dig("content", "story", "comet_sections", "context_layout", "story", "comet_sections", "metadata").nil?
          created_at = graphql_object["node"]["comet_sections"].dig("content", "story", "comet_sections", "context_layout", "story", "comet_sections", "metadata")&.first["story"]["creation_time"]
        else
          created_at = graphql_object["node"]["comet_sections"]["context_layout"]["story"]["comet_sections"]["metadata"].first["story"]["creation_time"]
        end

        has_video = false
      else
        graphql_object_array.find { |graphql_object| graphql_object.key?("viewer_actor") && graphql_object.key?("display_comments") }
        curr_media_object = graphql_object_array.find { |graphql_object| graphql_object.key?("currMedia") }
        raise Forki::ContentUnavailableError if curr_media_object.nil?

        creation_story_object = graphql_object_array.find { |graphql_object| graphql_object.key?("creation_story") && graphql_object.key?("message") }

        feedback_object = graphql_object_array.find { |graphql_object| graphql_object.has_key?("comet_ufi_summary_and_actions_renderer") }["comet_ufi_summary_and_actions_renderer"]["feedback"]

        if feedback_object.key?("top_reactions")
          feedback_object = feedback_object
        else
          # POSSIBLY OUT OF DATE
          feedback_object = feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]
        end

        share_count_object = feedback_object.fetch("share_count", {})

        poster = creation_story_object["creation_story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]

        if feedback_object.has_key?("cannot_see_top_custom_reactions")
          reaction_counts = extract_reaction_counts(feedback_object["cannot_see_top_custom_reactions"]["top_reactions"])
        else
          reaction_counts = extract_reaction_counts(feedback_object["top_reactions"])
        end

        id = curr_media_object["currMedia"]["id"],

        num_comments = feedback_object["comments_count_summary_renderer"]["feedback"]["total_comment_count"],
        if num_comments.nil? && feedback_object.has_key?("comments_count_summary_renderer")
          num_comments = feedback_object["comments_count_summary_renderer"]["feedback"]["comment_rendering_instance"]["comments"]["total_count"]
        end

        num_shares = share_count_object.fetch("count", nil)
        reshare_warning = feedback_object["should_show_reshare_warning"]
        image_url = curr_media_object["currMedia"]["image"]["uri"]
        text = (creation_story_object["message"] || {}).fetch("text", nil)
        profile_link = poster["url"]
        created_at = curr_media_object["currMedia"]["created_time"]
        has_video = false
      end

      post_details = {
        id: id,
        num_comments: num_comments,
        num_shares: num_shares,
        reshare_warning: reshare_warning,
        image_url: image_url,
        text: text,
        profile_link: profile_link,
        created_at: created_at,
        has_video: has_video
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

      if creation_story_object["feedback"].key?("cannot_see_top_custom_reactions")
        reaction_counts = extract_reaction_counts(creation_story_object["feedback"]["cannot_see_top_custom_reactions"]["top_reactions"])
      else
        reaction_counts = extract_reaction_counts(creation_story_object["feedback"]["top_reactions"])
      end

      post_details = {
        id: video_object["id"],
        num_comments: creation_story_object["feedback"]["total_comment_count"],
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
      if creation_story_object["feedback_context"]["feedback_target_with_context"].key?("cannot_see_top_custom_reactions")
        reaction_counts = extract_reaction_counts(creation_story_object["feedback_context"]["feedback_target_with_context"]["cannot_see_top_custom_reactions"]["top_reactions"])
      else
        reaction_counts = extract_reaction_counts(creation_story_object["feedback_context"]["feedback_target_with_context"]["top_reactions"])
      end

      post_details = {
        id: creation_story_object["shareable"]["id"],
        num_comments: creation_story_object["feedback_context"]["feedback_target_with_context"]["total_comment_count"],
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

    def take_screenshot
      # First check whether post being scraped has a fact check overlay. If it does clear it.
      begin
        find('div[aria-label=" See Photo "]').click() || find('div[aria-label=" See Video "]').click()
      rescue Capybara::ElementNotFound
        # Do nothing if element not found
      end

      begin
        # rubocop:disable Lint/Debugger
        save_screenshot("#{Forki.temp_storage_location}/facebook_screenshot_#{SecureRandom.uuid}.png")
        # rubocop:enable Lint/Debugger
      rescue Selenium::WebDriver::Error::TimeoutError
        raise Net::ReadTimeout
      end
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
          post_data[:screenshot_file] = take_screenshot
          break
        rescue Net::ReadTimeout; end

        sleep(5)
      end

      # page.quit # Close browser between page navigation to prevent cache folder access issues
      post_data[:user] = user_url.present? ? User.lookup(user_url)&.first : {}
      page.quit

      post_data
    rescue Net::ReadTimeout => e
      puts "Time out error: #{e}"
      puts e.backtrace
      raise Forki::RetryableError # This insures it'll eventually be retried by Hypatia
    rescue StandardError => e
      raise e
      raise Forki::RetryableError
    ensure
      # `page` here can be broken already. In which case we want to raise an error so it's retried later
      begin
        page.quit
      rescue Curl::Err::ConnectionFailedError
        raise Forki::RetryableError # This insures it'll eventually be retried by Hypatia
      rescue StandardError => e
        puts "Error closing browser: #{e}"
        raise e
        # raise Forki::RetryableError
      end
    end
  end
end

require_relative "sieves/video_sieves/video_sieve"
