# Image URLS
## Non-watermarked:
# * https://skeb.imgix.net/requests/199886_0?bg=%23fff&auto=format&w=800&s=5a6a908ab964fcdfc4713fad179fe715
## Watermarked:
# * https://skeb.imgix.net/requests/73290_0?bg=%23fff&auto=format&txtfont=bold&txtshad=70&txtclr=BFFFFFFF&txtalign=middle%2Ccenter&txtsize=150&txt=SAMPLE&w=800&s=4843435cff85d623b1f657209d131526
## Full Size (found in commissioner_upload):
# * https://skeb.imgix.net/requests/53269_1?bg=%23fff&fm=png&dl=53269.png&w=1.0&h=1.0&s=44588ea9c41881049e392adb1df21cce
#
# The signature is required and tied to the parameters. Doesn't seem like it's possible to reverse engineer it to remove the watermark, unfortunately.
#
# Page URLS
# * https://skeb.jp/@OrvMZ/works/3 (non-watermarked)
# * https://skeb.jp/@OrvMZ/works/1 (separated request and client's message after delivery. We can't get the latter)
# * https://skeb.jp/@asanagi/works/16 (age-restricted, watermarked)
# * https://skeb.jp/@asanagi/works/6 (private, returns 404)
#
# Profile URLS
# Since skeb forces login through twitter, usernames are the same as twitter
# * https://skeb.jp/@asanagi

module Sources
  module Strategies
    class Skeb < Base
      PROFILE_URL = %r{https?://(?:www\.)?skeb\.jp/@(?<artist_name>\w+)}i

      PAGE_URL    = %r{#{PROFILE_URL}/works/(?<illust_id>\d+)}i

      IMAGE_URL   = %r{https?://(?:www\.)?skeb\.imgix\.net/requests/[\d_]+\?.*}i

      def domains
        ["skeb.jp"]
      end

      def match?
        return false if parsed_url.nil?
        parsed_url.domain.in?(domains) || parsed_url.host == "skeb.imgix.net"
      end

      def site_name
        "Skeb"
      end

      def image_urls
        if url =~ IMAGE_URL
          [url]
        elsif page.present?
          [page.text[/window\.__NUXT__=.*,preview_url:"(.*?)",/, 1].gsub("\\u002F", "/")]
        else
          []
        end
      end

      def page_url
        urls.map { |u| u if u =~ PAGE_URL }.compact.first
      end

      def normalize_for_source
        page_url
      end

      def page
        return if page_url.blank?
        response = http.cache(1.minute).get(page_url)
        return nil unless response.status == 200
        # The status check is required for private commissions, which return 404

        response.parse
      end

      def profile_url
        return nil if artist_name.blank?
        "https://skeb.jp/@#{artist_name}"
      end

      def artist_name
        url[PROFILE_URL, :artist_name]
      end

      def display_name
        page&.at("title")&.text&.match(/.*by (.*?) \| skeb/i).to_a[1]
      end

      def other_names
        [display_name].compact.uniq
      end

      def artist_commentary_desc
        # skeb "titles" are not needed: it's just the first few characters of the description
        return if page.blank?
        page.at("[property='og:description']")["content"]
      end

      def client_response
        return if page.blank?
        page.text[/window\.__NUXT__=.*,thanks:"(.*?)",/, 1]&.gsub(/\\n/, "\n")
      end

      def dtext_artist_commentary_desc
        if client_response.present? && artist_commentary_desc.present?
          "h5. Original Request:\n#{artist_commentary_desc}\n\nh5. Client Response:\n#{client_response}"
        else
          artist_commentary_desc
        end
      end
    end
  end
end
