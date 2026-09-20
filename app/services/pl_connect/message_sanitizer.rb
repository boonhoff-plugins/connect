# frozen_string_literal: true

module PlConnect
  # MessageSanitizer
  #
  # Single place where chat message HTML is cleaned before it is persisted.
  #
  # == Why sanitise on write, not on read
  # The message body is written once and read thousands of times (every render
  # of the conversation, every search hit, every notification preview). Cleaning
  # on write means a body that reached the database is already safe, so no read
  # path can accidentally forget to escape it. It also means a future bug in a
  # view cannot turn into a stored XSS, because the payload never made it in.
  #
  # == Allow list
  # Deliberately narrow. Chat needs basic formatting, links, lists and code —
  # nothing else. Notably absent and never allowed:
  #   * <script>, <style>, <iframe>, <object>, <embed>, <form>, <input>
  #   * any "on*" event handler attribute
  #   * the style attribute (CSS can be used for clickjacking overlays)
  #   * <img>, because an external image URL leaks the reader's IP address to a
  #     third party server the moment the message is displayed (GDPR Art. 6 —
  #     there is no legal basis for disclosing a reader's IP to an arbitrary
  #     host chosen by the sender). Images are supported as attachments, which
  #     are served from this application.
  module MessageSanitizer
    ALLOWED_TAGS = %w[
      p br div span strong b em i u s del ins
      ul ol li blockquote pre code
      h1 h2 h3 h4 h5 h6
      a
    ].freeze

    ALLOWED_ATTRIBUTES = %w[href title class data-mention-type data-mention-uuid].freeze

    # Only these URL schemes survive on links. Blocks javascript:, data: and
    # vbscript:, which are the classic ways to smuggle script execution into an
    # href even when the tag itself is allowed.
    ALLOWED_PROTOCOLS = %w[http https mailto].freeze

    # Elements whose *content* has to go as well, not just the tag.
    #
    # Rails::HTML5::SafeListSanitizer only drops the disallowed element and
    # keeps its text children, so "<script>alert(1)</script>" would survive as
    # the literal text "alert(1)" in the middle of the message. Harmless in
    # terms of execution, but confusing to read and a source of false positives
    # in the plain text search index, so these nodes are removed whole before
    # the allow list runs.
    STRIPPED_ELEMENTS = %w[script style noscript template iframe object embed applet].freeze

    module_function

    # Returns the cleaned HTML for storage in PlConnectChatMessageItem#body.
    def clean(html)
      return "" if html.blank?

      fragment = Nokogiri::HTML5.fragment(html.to_s)
      fragment.css(STRIPPED_ELEMENTS.join(",")).each(&:remove)

      Rails::HTML5::SafeListSanitizer.new.sanitize(
        fragment.to_html,
        tags: ALLOWED_TAGS,
        attributes: ALLOWED_ATTRIBUTES,
        protocols: ALLOWED_PROTOCOLS
      ).to_s
    end

    # Plain text version of the body, used for search, for the sidebar preview
    # and for push/e-mail notifications. Block level tags become spaces so that
    # "<p>a</p><p>b</p>" does not collapse into "ab".
    def to_plain_text(html)
      return "" if html.blank?

      text = html.to_s.gsub(%r{<br\s*/?>}i, " ").gsub(%r{</(p|div|li|h[1-6]|blockquote|pre)>}i, " ")
      text = Rails::HTML5::FullSanitizer.new.sanitize(text).to_s
      CGI.unescapeHTML(text).gsub(/\s+/, " ").strip
    end

    # Shortened plain text for the conversation list. Cuts on a whole character
    # boundary and never exceeds the database column width.
    def preview(html, limit: 200)
      to_plain_text(html).truncate(limit)
    end
  end
end
