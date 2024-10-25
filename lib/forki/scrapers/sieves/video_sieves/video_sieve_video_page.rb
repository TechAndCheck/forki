class VideoSieveVideoPage < VideoSieve
  # To check if it's valid for the inputted graphql objects
  def self.check(graphql_objects)
    story_node_object = self.extractor(graphql_objects) # This will error out
    return false unless story_node_object["content"]["story"]["attachments"].first["styles"]["attachment"].has_key?("media")

    feedback_object = story_node_object["feedback"]["story"]["feedback_context"]["feedback_target_with_context"]["ufi_renderer"]["feedback"]["comet_ufi_summary_and_actions_renderer"]["feedback"]
    # This is what differs from video_sieve_video_page_2.rb, where this key is unnested
    return false unless feedback_object.has_key?("cannot_see_top_custom_reactions")

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
    extracted_text = self.extractor(graphql_objects)

    story_object = extracted_text["content"]["story"]
    video_object = extracted_text["content"]["story"]["attachments"].first["styles"]["attachment"]["media"]
    feedback_object = extracted_text["feedback"]["story"]["feedback_context"]["feedback_target_with_context"]["ufi_renderer"]["feedback"]["comet_ufi_summary_and_actions_renderer"]["feedback"]

    video_preview_image_url = video_object["preferred_thumbnail"]["image"]["uri"]
    video_url = video_object["browser_native_hd_url"]
    video_url = video_object["browser_native_sd_url"] if video_url.nil?

    {
      id: video_object["id"],
      num_comments: feedback_object["total_comment_count"],
      num_shared: feedback_object["share_count"]["count"],
      num_views: nil,
      reshare_warning: feedback_object["should_show_reshare_warning"],
      video_preview_image_url: video_preview_image_url,
      video_url: video_url,
      text: story_object["message"]["text"],
      created_at: video_object["publish_time"],
      profile_link: story_object["actors"].first["url"],
      has_video: true,
      video_preview_image_file: Forki.retrieve_media(video_preview_image_url),
      video_file: Forki.retrieve_media(video_url),
      reactions: feedback_object["cannot_see_top_custom_reactions"]["top_reactions"]["edges"]
    }
  end

private

  def self.extractor(graphql_objects)
    story_node_object = graphql_objects.find { |graphql_object| graphql_object.key? "node" }&.fetch("node", nil) # user posted video
    story_node_object["comet_sections"]
  end
end
