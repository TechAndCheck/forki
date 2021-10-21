# frozen_string_literal: true

require "typhoeus"
require "Date"

module Zorki
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


      s=5  # block notifications
      num_comments = find_num_comments
      num_shares = find_num_shares
      num_views = find_num_views
      reactions = find_reactions
      has_video = ! num_views.nil?
      s = 3

      if has_video
        mobile_url = media_url.sub("www", "m")
        visit mobile_url
        video_div = all("div").find { |div| (!div["data-store"].nil?) && div["data-store"].include?("videoID") }
        video_url = JSON.parse(video_div["data-store"])["src"]
        video_file_name = Zorki.retrieve_media(video_url)

        video_url_pattern = /url\(\"(.*)?\"\)/
        video_preview_image_url = video_url_pattern.match(video_div.find("i")[:style]).captures.first
        video_preview_image = Zorki.retrieve_media(video_preview_image_url)
      else
        image_element = all("img").find { |img| img["data-visualcompletion"] == "media-vc-image" }
        image_url = image_element["src"]
        image_file_name = Zorki.retrieve_media(image_url)
      end

      user_elem = all("h2").find { |h2| h2.all("a").length == 1}
      user_url = user_elem.find("a")["href"]

      # fb_id_pattern = /facebook.com\/(.*?)\//
      # user_id = fb_id_pattern.match(user_url).captures.first

      text = "asa's post. back off"


      # date_pattern = /.*?, #{Regexp.quote(month)} [0-9]{1,2},/

      # match 3h, 3d, 3w, October 3
      # match date regex intsead of aria label
      date_elem = all("a").find { |a| (/[0-9]{1,2}(h|w|d)/.match(a["aria-label"])) || (/[0-9]{1,2}/.match(a["aria-label"]) and Date::MONTHNAMES[1..].any? { | month| a["aria-label"].include? month } ) }
      date_elem.hover
      sleep 5  # wait for hover tooltip

      # matches "..., October 14, "
      date_span = all("span").filter { |span| Date::MONTHNAMES[1..].any? { |month|  /.*?, #{Regexp.quote(month)} [0-9]{1,2},/.match(span.text) } }.first
      date = DateTime.strptime(date_span.text, "%A, %B %d, %Y at %l:%M %p")

      user = User.lookup(user_url)
      {
        image_file_name: image_file_name,
        video_file_name: video_file_name,
        video_preview_image: video_preview_image,
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
