# frozen_string_literal: true

require "typhoeus"
require "Date"

module Forki
  class PostScraper < Scraper

    # Finds the number of comments on a post
    def find_num_comments
      comment_pattern = /[0-9KM,\. ]+Comments/
      comments_span = all("span").find { |s| s.text(:all) =~ comment_pattern}
      extract_num_interactions(comments_span)
    end

    # Finds the number of times a post has been shared
    def find_num_shares
      shares_pattern = /[0-9KM\., ]+Shares/
      spans = all("span")
      shares_span = spans.find { |s| s.text(:all) =~ shares_pattern}
      extract_num_interactions(shares_span)
    end

    # Finds the number of times a (video) post has been viewed.
    def find_num_views
      views_pattern = /[0-9MK, ]+Views/
      spans = all("span")
      views_span = spans.find { | s| s.text(:all) =~ views_pattern}
      extract_num_interactions(views_span)
    end

    # Extracts an integer out of a string that describes the number of interactions on a post
    # e.g. "4K Comments" returns 4000
    # e.g. "131 Shares" returns 131
    def extract_num_interactions(element)
      return unless element
      num_pattern = /[0-9KM\.]+/
      interaction_num_text = num_pattern.match(element.text(:all))[0]

      if interaction_num_text.include?(".")  # e.g. "2.2K"
        interaction_num_text.to_i + interaction_num_text[-2].to_i * 100
      elsif interaction_num_text.include?("K") # e.g. "13K"
        interaction_num_text.to_i * 1000
      elsif interaction_num_text.include?("M") # e.g. "13M"
        interaction_num_text.to_i * 1_000_000
      else  # e.g. "15"
        interaction_num_text.to_i
      end
    end

    # Finds the types/counts of reactions to a post
    def find_reactions
      reactions = {}
      reaction_divs = locate_reaction_divs

      reaction_divs.each do | div |
        next unless div.all("img", visible: :all).length > 0
        reaction_img = div.find("img", visible: :all)
        reaction_type = determine_reaction_type(reaction_img)
        num_reactions = extract_num_interactions(div)
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
      unless exit_fact_check_button.nil?
        exit_fact_check_button.click
      end
    end

    def find_post_creation_date
      # This is horrible and I'll re-write it, but it basically checks spans to see whether one of their attributes matches a date string or contains a month+day reference
      # Depending on how old the post is, that string might look like "3h...", "3d...", "...October 3, 2021..."
      # obviously it deserves its own method. Soon to come

      months = Date::MONTHNAMES[1..].join("|")
      relative_timestamp_pattern = /[0-9]{1,2}(h|w|d)/
      month_day_pattern = /(#{months}) [0-9]{1,2}/
      yesterday_pattern = /Yesterday at/

      date_elem = all("a").find { |a| relative_timestamp_pattern.match(a["aria-label"]) ||
                                            month_day_pattern.match(a["aria-label"]) ||
                                            yesterday_pattern.match(a["aria-label"])}
      # date_elem = all("a").find { |a| (/[0-9]{1,2}(h|w|d)/.match(a["aria-label"])) || (/[0-9]{1,2}/.match(a["aria-label"]) and Date::MONTHNAMES[1..].any? { | month| a["aria-label"].include? month } ) }
      date_elem.hover  # hovering over the date element found above surfaces a tooltip with the full date string
      sleep 2  # wait for the tooltip to appear after we hover

      # We want to match a datestring in the tooltip that looks like "...Thursday, October 31, ..."
      # date_span = all("span").filter { |span| Date::MONTHNAMES[1..].any? { |month|  /.*?, #{Regexp.quote(month)} [0-9]{1,2},/.match(span.text) } }.first
      date_span = all("span").filter { |span| /.*?, (#{months}) [0-9]{1,2},/.match(span.text) } .first

      date = DateTime.strptime(date_span.text, "%A, %B %d, %Y at %l:%M %p")

    end

    def parse(url)
      # Stuff we need to get from the DOM (implemented is starred):
      # - User *
      # - Text *
      # - Image * / Images * / Video *
      # - Date *
      # - Number of likes *
      # - Hashtags

      validate_and_load_page(url)
      escape_fact_check_filter

      sleep 3
      num_comments = find_num_comments
      num_shares = find_num_shares
      num_views = find_num_views
      reactions = find_reactions
      refresh # closes reaction modal
      sleep 2

      has_video = ! num_views.nil?
      post_creation_date = find_post_creation_date

      # If a Facebook post has video content, we load the mobile version of it and extract the video url
      # Unfortunately, the desktop version has a blob link that's too much trouble to mess with
      if has_video
        mobile_url = url.sub("www", "m")
        visit mobile_url
        video_div = all("div").find { |div| (!div["data-store"].nil?) && div["data-store"].include?("videoID") }
        video_url = JSON.parse(video_div["data-store"])["src"]
        video_file_name = Forki.retrieve_media(video_url)

        video_url_pattern = /url\(\"(.*)?\"\)/
        video_preview_image_url = video_url_pattern.match(video_div.find("i")[:style]).captures.first
        video_preview_image = Forki.retrieve_media(video_preview_image_url)

        user_elem = all("h3").find { |h3| h3.all("a").length == 1}
      else
        image_element = all("img").find { |img| img["data-visualcompletion"] == "media-vc-image" }
        image_url = image_element["src"]
        image_file_name = Forki.retrieve_media(image_url)

        # Profile names are h2'd and contain links. They're the only elements like that... for now...
        user_elem = all("h2").find { |h2| h2.all("a").length == 1}
      end

      user_url = user_elem.find("a")["href"]
      text = "asa's post. back off"  # still need to find a way to extract post text.

      # This user object is bare right now. Different types of profiles have different information
      # And I think people get to choose which attributes appear on their profiles.
      # On certain profiles, an attribute will appear in one place, and onother profiles, another
      # But that's a problem for next week
      user = User.lookup(user_url)
      {
        image_file_name: image_file_name,
        video_file_name: video_file_name,
        video_preview_image: video_preview_image,
        video_preview_image_url: video_preview_image_url,
        num_comments: num_comments,
        has_video: has_video,
        reactions: reactions,
        num_views: num_views,
        num_shares: num_shares,
        text: text,
        date: post_creation_date,
        user: user,
        url: url
      }
    end
  end
end
