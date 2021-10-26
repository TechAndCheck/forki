# frozen_string_literal: true

require "typhoeus"
require "Date"

module Forki
  class PostScraper < Scraper
    def parse(url)
      # Stuff we need to get from the DOM (implemented is starred):
      # - User *
      # - Text *
      # - Image * / Images * / Video *
      # - Date *
      # - Number of likes *
      # - Hashtags

      login

      # visit "https://www.facebook.com/humansofnewyork/photos/a.102107073196735/6698806303526746/"  # page photo
      # visit "https://www.facebook.com/watch/?v=258470355199081"  # watch video
      # media_url = "https://www.facebook.com/photo.php?fbid=1313009878767692&set=a.130724406996251&type=3&theater" # personal photo
      # media_url = "https://www.facebook.com/ILMFOrg/photos/a.207535503185392/905395720066030"
      # visit "https://www.facebook.com/ILMFOrg/photos/a.207535503185392/905395720066030"
      visit url

      # escape fact check filter
      exit_fact_check_popup = all("span").filter { |span| span.text == "See Photo" || span.text == "See Video"}.first
      unless exit_fact_check_popup.nil?
        exit_fact_check_popup.click
      end

      sleep 3
      num_comments = find_num_comments
      num_shares = find_num_shares
      num_views = find_num_views
      reactions = find_reactions
      has_video = ! num_views.nil?

      # This is horrible and I'll re-write it, but it basically checks spans to see whether one of their attributes matches a date string or contains a month+day reference
      # Depending on how old the post is, that string might look like "3h...", "3d...", "...October 3, 2021..."
      # obviously it deserves its own method. Soon to come

      date_elem = all("a").find { |a| (/[0-9]{1,2}(h|w|d)/.match(a["aria-label"])) || (/[0-9]{1,2}/.match(a["aria-label"]) and Date::MONTHNAMES[1..].any? { | month| a["aria-label"].include? month } ) }
      date_elem.hover  # hovering over the date element found above surfaces a tooltip with the full date string
      sleep 2  # wait for the tooltip to appear after we hover

      # We want to match a datestring in the tooltip that looks like "...Thursday, October 31, ..."
      # date_span = all("span").filter { |span| Date::MONTHNAMES[1..].any? { |month|  /.*?, #{Regexp.quote(month)} [0-9]{1,2},/.match(span.text) } }.first
      months = Date::MONTHNAMES[1..].join("|")
      date_span = all("span").filter { |span| /.*?, (#{months}) [0-9]{1,2},/.match(span.text) } .first

      date = DateTime.strptime(date_span.text, "%A, %B %d, %Y at %l:%M %p")

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
        date: date,
        user: user,
        url: url
      }
    end
  end
end
