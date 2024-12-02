# rubocop:disable Metrics/ClassLength
class VideoImageSieveMixed < VideoSieve
  # To check if it's valid for the inputted graphql objects
  def self.check(graphql_objects)
    story_node_object = self.extractor(graphql_objects)
    return false if story_node_object.nil?

    media_objects = story_node_object.dig("comet_sections", "content", "story", "attachments")&.first&.dig("styles", "attachment")
    media_objects.dig("all_subattachments", "nodes") if media_objects

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
    story_node_object   = self.extractor(graphql_objects)

    feedback_object     = extract_feedback_object(story_node_object)
    reaction_counts     = extract_reactions(feedback_object)
    share_count_object  = extract_share_count(feedback_object)
    text                = extract_text(story_node_object)
    num_comments        = extract_comments_count(feedback_object)
    reshare_warning     = extract_reshare_warning(feedback_object)
    video_view_count    = extract_video_views(feedback_object)
    creation_date       = extract_creation_date(story_node_object)
    profile_link        = extract_profile_link(story_node_object)

    media_urls          = extract_media_urls(story_node_object)

    video_urls          = []
    video_preview_urls  = []
    image_urls          = []
    media_urls.each do |media_url|
      if media_url[:type] == "Video"
        video_urls << media_url[:media_url]
        video_preview_urls << media_url[:preview_image_url]
      elsif media_url[:type] == "Photo"
        image_urls << media_url[:media_url]
      end
    end

    post_details = {
      id: story_node_object["id"],
      num_comments: num_comments,
      num_shares: share_count_object.fetch("count", nil),
      num_views: video_view_count,
      reshare_warning: reshare_warning,
      video_preview_image_urls: video_preview_urls,
      video_urls: video_urls,
      image_urls: image_urls,
      text: text,
      created_at: creation_date,
      profile_link: profile_link,
      has_video: true,
      reactions: reaction_counts
    }
    post_details[:video_preview_image_files] = video_preview_urls.map { |url| Forki.retrieve_media(url) }
    post_details[:video_files] = video_urls.map { |url| Forki.retrieve_media(url) }
    post_details[:image_files] = image_urls.map { |url| Forki.retrieve_media(url) }

    post_details
  end

private

  def self.extractor(graphql_objects)
    story_node_objects = graphql_objects.find do |go|
      go.dig("node") # user posted video
    end

    story_node_objects.dig("node")
  end

  def self.extract_feedback_object(story_node_object)
    feedback_object = story_node_object["comet_sections"]["feedback"]["story"]["story_ufi_container"]["story"]["feedback_context"]["feedback_target_with_context"]
    feedback_object["comet_ufi_summary_and_actions_renderer"]["feedback"]
  end

  def self.extract_reactions(feedback_object)
    feedback_object = feedback_object["cannot_see_top_custom_reactions"] if feedback_object.key?("cannot_see_top_custom_reactions")
    feedback_object["top_reactions"]
  end

  def self.extract_share_count(feedback_object)
    feedback_object.fetch("share_count", {})
  end

  def self.extract_text(story_node_object)
    text = ""
    if story_node_object["comet_sections"]["content"]["story"]["comet_sections"].key?("message") && !story_node_object["comet_sections"]["content"]["story"]["comet_sections"]["message"].nil?
      text = story_node_object["comet_sections"]["content"]["story"]["comet_sections"]["message"]["story"]["message"]["text"]
    end

    text
  end

  def self.extract_comments_count(feedback_object)
    feedback_object["comments_count_summary_renderer"]["feedback"]["comment_rendering_instance"]["comments"]["total_count"]
  end

  def self.extract_reshare_warning(feedback_object)
    feedback_object["should_show_reshare_warning"]
  end

  def self.extract_video_views(feedback_object)
    feedback_object["video_view_count"]
  end

  def self.extract_media_urls(story_node_object)
    media_object_array = story_node_object["comet_sections"]["content"]["story"]["attachments"].first["styles"]["attachment"]["all_subattachments"]["nodes"]
    media_object_array.map do |media_object|
      media_object = media_object["media"]
      type = media_object["__typename"]

      case type
      when "Video"
        possible_subsearch = media_object.dig("video_grid_renderer", "video")
        media_object = media_object.dig("video_grid_renderer", "video") unless possible_subsearch.nil?

        if media_object.has_key?("videoDeliveryResponseFragment") && !media_object["videoDeliveryResponseFragment"].nil?
          progressive_urls_wrapper = media_object["videoDeliveryResponseFragment"]["videoDeliveryResponseResult"]
          media_url = progressive_urls_wrapper["progressive_urls"].find_all { |object| !object["progressive_url"].nil? }.last["progressive_url"]
        else
          video_object_url_subsearch = media_object["videoDeliveryLegacyFields"] if media_object.has_key?("videoDeliveryLegacyFields")
          media_url = video_object_url_subsearch["browser_native_hd_url"] || video_object_url_subsearch["browser_native_sd_url"]
        end

        preview_image_url = media_object["thumbnailImage"]["uri"]
      when "Photo"
        media_url = media_object["image"]["uri"]
      end

      { media_url: media_url, preview_image_url: preview_image_url, type: type, id: media_object["id"] }
    end
  end

  def self.extract_creation_date(story_node_object)
    story_node_object["comet_sections"]["context_layout"]["story"]["comet_sections"]["metadata"][0]["story"]["creation_time"]
  end

  def self.extract_profile_link(story_node_object)
    story_node_object["comet_sections"]["context_layout"]["story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]["url"]
  end
end
