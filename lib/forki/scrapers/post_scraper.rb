# frozen_string_literal: true

require "typhoeus"
require "Date"

module Forki
  class PostScraper < Scraper

    # Finds the number of comments on a post
    def find_num_comments
      comment_pattern = /[0-9KM,\. ]+Comments/
      comments_span = all("span").find { |s| s.text(:all) =~ comment_pattern}
      extract_int_from_num_element(comments_span)
    end

    # Finds the number of times a post has been shared
    def find_num_shares
      shares_pattern = /[0-9KM\., ]+Shares/
      spans = all("span")
      shares_span = spans.find { |s| s.text(:all) =~ shares_pattern}
      extract_int_from_num_element(shares_span)
    end

    # Finds the number of times a (video) post has been viewed.
    def find_num_views
      views_pattern = /[0-9MK, ]+Views/
      spans = all("span")
      views_span = spans.find { | s| s.text(:all) =~ views_pattern}
      extract_int_from_num_element(views_span)
    end


    # Finds the types/counts of reactions to a post
    def find_reactions
      reactions = {}
      reaction_divs = locate_reaction_divs

      reaction_divs.each do | div |
        next unless div.all("img", visible: :all).length > 0
        reaction_img = div.find("img", visible: :all)
        reaction_type = determine_reaction_type(reaction_img)
        num_reactions = extract_int_from_num_element(div)
        reactions[reaction_type.to_sym] = num_reactions
      end
      reactions
    end

    # Finds the divs containing individual reaction counts from within the reaction modal
    def locate_reaction_divs
      all("img").find { |s| s["src"] =~ /svg/}.click  # click on a reaction emoji to open the reaction modal
      popup = find(:xpath, '//div[@aria-label="Reactions"]')  # select the modal element
      popup_header = popup.first("div")  # select the "header" div where reaction counts are stored
      reaction_divs = popup_header.all("div", visible: :all)  # select divs (containing reaction pictures) with aria-hidden attribute.

      # Throw away divs that contain text instead of reaction emoji
      reaction_divs.filter { |div| ! (div["aria-hidden"].nil? or div.text.include?("All") or div.text.include?("More")) }
    end

    # Finds the appropriate label for a given reaction emoji image by comparing it to some locally stored and labeled images
    def determine_reaction_type(img_elem)
      # I need to set a threshold likeness val, below which we just throw away an emoji.
      # Otherwise an emoji in the DOM will match (poorly) to another emoji and possibly overwrite its value in the hash we build above
      download_image(img_elem)
      img_hash = DHashVips::IDHash.fingerprint "temp/emoji.png"
      best_match = [nil, 1024]
      Dir.each_child("reactions/") do |filename|
        next unless filename.include? "png"
        match_hash = DHashVips::IDHash.fingerprint "reactions/#{filename}"
        distance = DHashVips::IDHash.distance(img_hash, match_hash)
        if distance < best_match[1]
          best_match = [filename, distance]  # the local image most similar to the image on the webpage is our match
        end
      end
      best_match[0].delete_suffix(".png")
    end

    def escape_fact_check_filter
      exit_fact_check_button = all("span").filter { |span| span.text == "See Photo" || span.text == "See Video"}.first
      # unless exit_fact_check_button.nil?
      #   exit_fact_check_button.click
      # end
      exit_fact_check_button.click unless exit_fact_check_button.nil?
    end

    def access_post_directly
      months = Date::MONTHNAMES[1..].join("|")
      relative_timestamp_pattern = /[0-9]{1,2}(h|w|d)/
      month_day_pattern = /(#{months}) [0-9]{1,2}/
      yesterday_pattern = /Yesterday at/

      # Find the date "summary" element which can contain a relative date descriptino (e.g. "2h ago") or a month-day combination (e.g. "October 26")
      date_elem = all("a").find { |a| relative_timestamp_pattern.match(a["aria-label"]) ||
        month_day_pattern.match(a["aria-label"]) ||
        yesterday_pattern.match(a["aria-label"])}
      date_elem.click unless date_elem.nil?

      video_elem = first("video")
      video_elem.find(:xpath, "..").click
    end
      # Finds and returns the post creation date
    def find_post_creation_date
      months = Date::MONTHNAMES[1..].join("|")
      relative_timestamp_pattern = /[0-9]{1,2}(h|w|d)/
      month_day_pattern = /(#{months}) [0-9]{1,2}/
      yesterday_pattern = /Yesterday at/

      # Find the date "summary" element which can contain a relative date descriptino (e.g. "2h ago") or a month-day combination (e.g. "October 26")
      date_elem = all("a").find { |a| relative_timestamp_pattern.match(a["aria-label"]) ||
                                            month_day_pattern.match(a["aria-label"]) ||
                                            yesterday_pattern.match(a["aria-label"])}
      date_elem.hover  # hovering over the date summary element surfaces a tooltip with the full date string
      sleep 2  # wait for the tooltip to appear after we hover

      # Find the tooltip span. Its text should look like "...Tuesday, October 26, ..."
      date_span = all("span").filter { |span| /.*?, (#{months}) [0-9]{1,2},/.match(span.text) } .first

      DateTime.strptime(date_span.text, "%A, %B %d, %Y at %l:%M %p")
    end

    # Extracts video-releated data from a post. Uses the mobile page to access the video file
    def extract_video_data(url)
      video_url_pattern = /url\(\"(.*)?\"\)/
      mobile_url = url.sub("www", "m")
      visit mobile_url

      video_div = all("div").find { |div| (!div["data-store"].nil?) && div["data-store"].include?("videoID") }
      video_url = JSON.parse(video_div["data-store"])["src"]
      video_file_name = Forki.retrieve_media(video_url)
      video_preview_image_url = video_url_pattern.match(video_div.find("i")[:style]).captures.first
      video_preview_image = Forki.retrieve_media(video_preview_image_url)

      {
        video_url: video_url,
        video_file_name: video_file_name,
        video_preview_image_url: video_preview_image_url,
        video_preview_image: video_preview_image
      }
    end

    def extract_image_data
      image_element = all("img").find { |img| img["data-visualcompletion"] == "media-vc-image" }
      image_url = image_element["src"]
      {
        image_url: image_url,
        image_file_name: Forki.retrieve_media(image_url)
      }
    end


    def extract_post_data(gql_strings)
      gql_objects = gql_strings.map { |gql_obj| JSON.parse(gql_obj) }
      post_has_video = gql_objects.any? { |gql_object| gql_object.keys.include?("video") }
      post_has_video ? extract_vid_post_data(gql_strings) : extract_img_post_data(gql_objects)

    end

    def extract_img_post_data(gql_obj_array)
      viewer_actor_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("viewer_actor") && gql_object.keys.include?("display_comments") }
      cur_media_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("currMedia") }
      creation_story_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("creation_story") && gql_object.keys.include?("message") }
      poster = creation_story_obj["creation_story"]["comet_sections"]["actor_photo"]["story"]["actors"][0]
      # reaction_counts = extract_reaction_counts(viewer_actor_obj["comet_ufi_summary_and_actions_renderer"]["feedback"]["top_reactions"])
      reaction_counts = extract_reaction_counts(viewer_actor_obj["comet_ufi_summary_and_actions_renderer"]["feedback"]["top_reactions"])
      post_details = {
        num_comments: viewer_actor_obj["comment_count"]["total_count"],
        num_shares: viewer_actor_obj["comet_ufi_summary_and_actions_renderer"]["feedback"]["share_count"]["count"],
        reshare_warning: viewer_actor_obj["comet_ufi_summary_and_actions_renderer"]["feedback"]["share_count"]["count"],
        image_url: cur_media_obj["currMedia"]["image"]["uri"],
        text: (creation_story_obj["message"] || {}).fetch("text", nil),
        # profile_image_url: poster["profile_picture"]["uri"],
        profile_link: poster["url"],
        # profile_name: poster["name"],
        created_at: cur_media_obj["currMedia"]["created_time"],
        has_video: false
      }
      post_details[:image_file_name] = Forki.retrieve_media(post_details[:image_url])
      # post_details.merge(reaction_counts)
      post_details[:reactions] = reaction_counts
      post_details
    end

    def extract_vid_post_data_from_watch_page(gql_strs)
      return extract_live_vid_post_data_from_watch_page(gql_strs) if current_url.include?("live")
      video_obj = gql_strs.map { |g| JSON.parse(g) }.find { |x| x.keys.include?("video") }
      creation_story_obj = JSON.parse(gql_strs.find { |gql| (gql.include?("creation_story")) && (gql.include?("live_status")) } )
      video_url = creation_story_obj["creation_story"]["shareable"]["url"].gsub("\\", "")
      reaction_counts = extract_reaction_counts(creation_story_obj["feedback"]["top_reactions"])
      post_details = {
        num_comments: creation_story_obj["feedback"]["comment_count"]["total_count"],
        num_shares: nil, # Not present for watch feed videos?
        num_views: creation_story_obj["feedback"]["video_view_count_renderer"]["feedback"]["video_view_count"],
        reshare_warning: creation_story_obj["feedback"]["should_show_reshare_warning"],
        video_preview_image_url: video_obj["video"]["story"]["attachments"][0]["media"]["preferred_thumbnail"]["image"]["uri"],
        video_url: video_url,
        text: (creation_story_obj["creation_story"]["message"] || {})["text"],
        created_at: video_obj["video"]["story"]["attachments"][0]["media"]["publish_time"],
        profile_link: video_url[..video_url.index("/videos")],
        has_video: true
      }
      post_details[:video_preview_image_file_name] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file_name] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = reaction_counts
      post_details

    end
    def extract_live_vid_post_data_from_watch_page(gql_strs)
      # creation_story_str = gql_strs.filter { |gql| (gql.include? "videos") && (gql.include? "creation_story") }
      # sleep 2
      creation_story_obj = JSON.parse(gql_strs.find { |gql| (gql.include? "comment_count") && (gql.include? "creation_story") })["video"]["creation_story"]
      video_url = creation_story_obj["shareable"]["url"].gsub("\\", "")
      reaction_counts = extract_reaction_counts(creation_story_obj["feedback_context"]["feedback_target_with_context"]["top_reactions"])
      post_details = {
        num_comments: creation_story_obj["feedback_context"]["feedback_target_with_context"]["comment_count"]["total_count"],
        num_shares: nil, # Not present for watch feed videos?
        num_views: find_num_views, # Need to navigate to original video post to get this.
        reshare_warning: creation_story_obj["feedback_context"]["feedback_target_with_context"]["should_show_reshare_warning"],
        video_preview_image_url: creation_story_obj["attachments"][0]["media"]["preferred_thumbnail"]["image"]["uri"],
        video_url: video_url,
        text: creation_story_obj["attachments"][0]["media"]["savable_description"]["text"],
        created_at: creation_story_obj["attachments"][0]["media"]["publish_time"],
        profile_link: video_url[..video_url.index("/videos")],
        has_video: true
      }
      post_details[:video_preview_image_file_name] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file_name] = Forki.retrieve_media(post_details[:video_url])
      post_details[:reactions] = reaction_counts
      post_details
    end

    def extract_vid_post_data(gql_strs)
      unless all("h1").find { |h1| h1.text.strip == "Watch" }.nil?
        return extract_vid_post_data_from_watch_page(gql_strs)
      end
      gql_obj_array = gql_strs.map { |gql_str| JSON.parse(gql_str) }
      feedback_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("creation_story") && gql_object.keys.include?("feedback")}
      sidepane_obj = gql_obj_array.find { |gql_object| gql_object.keys.include?("tahoe_sidepane_renderer") }
      video_obj = gql_obj_array.find { |gql_object| gql_object.keys == ["video"] }

      reaction_counts = extract_reaction_counts(feedback_obj["feedback"]["top_reactions"])
      share_count_obj = feedback_obj["feedback"].fetch("share_count", {})
      post_details = {
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
      post_details[:video_preview_image_file_name] = Forki.retrieve_media(post_details[:video_preview_image_url])
      post_details[:video_file_name] = Forki.retrieve_media(post_details[:video_url])
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
      # - User
      # - Text
      # - Image/Video *
      # - Multiple images
      # - Creation date *
      # - Reaction tallies *
      # - Number of views, comments, and shares *


      validate_and_load_page(url)
      # escape_fact_check_filter
      # sleep 3
      gql_strs = find_graphql_data_objects(page.html)
      post_data = extract_post_data(gql_strs)
      # post_data = {
      #   num_comments: find_num_comments,
      #   num_shares: find_num_shares,
      #   num_views: find_num_views,
      #   created_at: find_post_creation_date,
      #   text: "Asa's post",
      #   url: url,
      #   reactions: find_reactions
      # }
      # post_data[:has_video] = ! post_data[:num_views].nil?
      #
      # refresh # gets rid of the reaction modal
      # sleep 2
      #
      # if post_data[:has_video]
      #   media_data = extract_video_data(url)
      #   user_elem = all("h3").find { |h3| h3.all("a").length == 1}  # mobile page uses h3 for profile names
      # else
      #   media_data = extract_image_data
      #   user_elem = all("h2").find { |h2| h2.all("a").length == 1}  # desktop page uses h2 for profile names
      # end
      # post_data.update(media_data)
      #
      # user_url = user_elem.find("a")["href"]
      user_url = post_data[:profile_link]
      post_data[:url] = url
      post_data[:user] = User.lookup(user_url)

      post_data
    end
  end
end
