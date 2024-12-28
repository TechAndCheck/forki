# This is for the "watch" tab style videos https://www.facebook.com/watch/live/?v=394367115960503

class VideoSieveWatchTab < VideoSieve
  # To check if it's valid for the inputted graphql objects
  def self.check(graphql_objects)
    video_object = self.extractor(graphql_objects)
    return false if video_object.nil?

    video_object = video_object["attachments"]
    return false if video_object.nil?

    return false unless video_object.kind_of?(Array) && !video_object.empty?

    video_object = video_object.first
    return false unless video_object.kind_of?(Hash) && video_object.key?("media")

    true
  rescue StandardError
    false
  end

  # output the expected format of:
  #
  # post_details = {
  #   id: video_object["id"],
  #   num_comments: num_comments,
  #   num_shares: share_count_object.fetch("count", nil),
  #   num_views: feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["video_view_count"],
  #   reshare_warning: feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]["should_show_reshare_warning"],
  #   video_preview_image_url: video_object["preferred_thumbnail"]["image"]["uri"],
  #   video_url: video_object["browser_native_hd_url"] || video_object["browser_native_sd_url"],
  #   text: text,
  #   created_at: creation_date,
  #   profile_link: story_node_object["comet_sections"]["context_layout"]["story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]["url"],
  #   has_video: true
  # }
  # post_details[:video_preview_image_file] = Forki.retrieve_media(post_details[:video_preview_image_url])
  # post_details[:video_file] = Forki.retrieve_media(post_details[:video_url])
  # post_details[:reactions] = reaction_counts

  def self.sieve(graphql_objects)
    video_object = self.extractor(graphql_objects)
    text = self.extract_text_object(graphql_objects)

    video_url = video_object["attachments"]&.first.dig("media", "browser_native_sd_url")

    video_url = video_object.dig("short_form_video_context", "playback_video", "browser_native_hd_url") if video_url.nil?
    video_url = video_object.dig("short_form_video_context", "playback_video", "browser_native_sd_url") if video_url.nil?

    video_url = video_object["attachments"]&.first.dig("media", "videoDeliveryLegacyFields", "browser_native_hd_url") if video_url.nil?
    video_url = video_object["attachments"]&.first.dig("media", "videoDeliveryLegacyFields", "browser_native_sd_url") if video_url.nil?

    if video_url.nil? && video_object["attachments"].first["media"].has_key?("videoDeliveryResponseFragment")
      progressive_urls_wrapper = video_object["attachments"].first["media"]["videoDeliveryResponseFragment"]["videoDeliveryResponseResult"]
      video_url = progressive_urls_wrapper["progressive_urls"].find_all { |object| !object["progressive_url"].nil? }.last["progressive_url"]
    end
    # else
    #   video_object_url_subsearch = video_object
    #   video_object_url_subsearch = video_object_url_subsearch["videoDeliveryLegacyFields"] if video_object_url_subsearch.has_key?("videoDeliveryLegacyFields")
    #   video_url = video_object_url_subsearch["browser_native_hd_url"] || video_object_url_subsearch["browser_native_sd_url"]
    # end


    raise Forki::VideoSieveFailedError.new(sieve_class: "VideoSieveWatchTab") if video_url.nil?

    video_preview_image_url = video_object["attachments"]&.first.dig("media", "preferred_thumbnail", "image", "uri")
    video_preview_image_url = video_object["short_form_video_context"]["video"]["first_frame_thumbnail"] if video_preview_image_url.nil?

    raise Forki::VideoSieveFailedError.new(sieve_class: "VideoSieveWatchTab") if video_preview_image_url.nil?
    video_preview_image_urls = [video_preview_image_url]

    if !video_object["feedback_context"].nil?
      feedback_object = video_object["feedback_context"]["feedback_target_with_context"]
    else
      feedback_object = graphql_objects.find { |go| !go.dig("feedback", "total_comment_count").nil? }
      feedback_object = feedback_object["feedback"] if feedback_object.has_key?("feedback")
    end

    begin
      profile_link = video_object["attachments"].first["media"]["owner"]["url"]
    rescue StandardError
      profile_link = video_object["short_form_video_context"]["video_owner"]["url"]
    end

    if profile_link.nil?
      filtered_json = graphql_objects.find { |go| go.has_key? "attachments" }
      profile_link = filtered_json["attachments"].first["media"]["creation_story"]["comet_sections"]["title"]["story"]["actors"].first["url"]
    end

    begin
      if feedback_object.key?("cannot_see_top_custom_reactions")
        reactions = feedback_object["cannot_see_top_custom_reactions"]["top_reactions"]["edges"]
      else
        reactions = feedback_object["top_reactions"]["edges"]
      end
    rescue StandardError
      reactions = feedback_object["unified_reactors"]["count"]
    end

    {
      id: video_object.dig("shareable", "id") || video_object["attachments"].first["media"]["id"],
      num_comments: feedback_object["total_comment_count"],
      num_shared: nil, # This is not associated with these videos in this format
      num_views: feedback_object.dig("video_view_count_renderer", "feedback", "video_view_count"), # This is not associated with these videos in this format
      reshare_warning: feedback_object["should_show_reshare_warning"],
      video_preview_image_urls: video_preview_image_urls,
      video_url: video_url,
      text: text, # There is no text associated with these videos
      created_at: video_object["attachments"].first["media"]["publish_time"],
      profile_link: profile_link,
      has_video: true,
      video_preview_image_files: video_preview_image_urls.map { |url| Forki.retrieve_media(url) },
      video_files: [Forki.retrieve_media(video_url)],
      reactions: reactions
    }
  end

private

  def self.extractor(graphql_objects)
    video_objects = graphql_objects.filter do |go|
      go = go.first if go.kind_of?(Array) && !go.empty?
      go.has_key?("video")
    end

    story = video_objects.first.dig("video", "creation_story")
    story = video_objects.first.dig("video", "story") if story.nil?

    story
  end

  def self.extract_text_object(graphql_objects)
    attachment_objects = graphql_objects.filter do |go|
      go.has_key?("attachments")
    end

    attachment_object = attachment_objects.first&.dig("attachments")&.first&.dig("media")
    return nil if attachment_object.nil?

    text = attachment_object.dig("title", "text")
    if text&.empty?
      text = attachment_object.dig("creation_story", "comet_sections", "message", "story", "message", "text")
    end

    text
  end
end
