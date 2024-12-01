class VideoSieveReel < VideoSieve
  # To check if it's valid for the inputted graphql objects
  def self.check(graphql_objects)
    video_object = self.extractor(graphql_objects)

    return false unless video_object.has_key?("short_form_video_context")

    # In relation to video_sieve_reel_2
    comment_count = graphql_objects.filter do |go|
      go = go.first if go.kind_of?(Array) && !go.empty?
      !go.dig("feedback", "total_comment_count").nil?
    end.first

    return false unless comment_count.nil?

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


    feedback_object = graphql_objects.filter do |go|
      go = go.first if go.kind_of?(Array) && !go.empty?
      !go.dig("feedback", "top_level_comments").nil?
    end.first

    reels_feedback_renderer = graphql_objects.filter do |go|
      go.dig("reels_feedback_renderer")
    end.first

    reels_feedback_renderer["reels_feedback_renderer"]["story"]
    reshare_warning = video_object["short_form_video_context"]["playback_video"].dig("warning_screen_renderer", "cix_screen", "view_model", "__typename") == "OverlayWarningScreenViewModel"

    video_preview_image_urls = [video_object["short_form_video_context"]["playback_video"]["preferred_thumbnail"]["image"]["uri"]]
    video_url = video_object["short_form_video_context"]["playback_video"]["browser_native_hd_url"] || video_object["short_form_video_context"]["playback_video"]["browser_native_sd_url"]

    {
      id: video_object["short_form_video_context"]["video"]["id"],
      num_comments: feedback_object["feedback"]["top_level_comments"]["totalCountIncludingReplies"],
      num_shared: Forki::Scraper.extract_int_from_num_element(feedback_object["feedback"]["share_count_reduced"]),
      num_views: nil,
      reshare_warning: reshare_warning,
      video_preview_image_urls: video_preview_image_urls,
      video_url: video_url,
      text: nil, # Reels don't have text
      created_at: JSON.parse(feedback_object["tracking"])["page_insights"].first[1]["post_context"]["publish_time"], # Yea, this is weird
      profile_link: video_object["short_form_video_context"]["video_owner"]["url"],
      has_video: true,
      video_preview_image_files: video_preview_image_url.map { |url| Forki.retrieve_media(url) },
      video_files: [Forki.retrieve_media(video_url)],
      reactions: nil # Only available on comments it seems? Look into this again sometime
    }
  end

private

  def self.extractor(graphql_objects)
    video_objects = graphql_objects.filter do |go|
      go = go.first if go.kind_of?(Array) && !go.empty?
      go.has_key?("video")
    end

    video_objects.first.dig("video", "creation_story")
  end
end
