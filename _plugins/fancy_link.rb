require 'jekyll-octicons'

module Jekyll
  class FancyLinkTag < Liquid::Block
    def initialize(_, date, _)
      @date = date.strip
      super
    end

    def parse(tokens)
      super
    end

    def render(context)
      @context = context

      @url, @anchor = super.split("\n").reject(&:empty?).map(&:strip)

      [ '<span class="fancylink">',
          "<a href=\"#{@url}\">#{@anchor}</a>",
          "<span>",
            external_link, archive_link,
          "</span>",
        "</span>"
      ].join(" ")
    end

    private

    def external_link
      icon = Liquid::Template.parse('{% octicon link-external %}').render(@context)
      "<a href=\"#{@url}\" target=\"_blank\" alt=\"Pop Out\" title=\"Pop Out\">#{icon}</a>"
    end

    def archive_link
      return if @date.empty?

      icon = Liquid::Template.parse('{% octicon mirror %}').render(@context)
      "<a href=\"https://web.archive.org/web/#{@date}/#{@url}\" target=\"_blank\" alt=\"Open on archive.org\" title=\"Open on archive.org\">#{icon}</a>"
    end
  end

  Liquid::Template.register_tag('fancylink', Jekyll::FancyLinkTag)
end
