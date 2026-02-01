require 'jekyll-octicons'

module Jekyll
  class ExampleEmbedTag < Liquid::Tag
    def initialize(tag_name, text, tokens)
      @example = text.strip
      super
    end

    def render(context)
      @context = context

      name_parts = @example.split('/')
      lang = name_parts.first
      name = name_parts.last

      coerce_documents!

      document = collection.docs.detect do |document|
        document.relative_path == "_examples/#{@example}"
      end

      if document.nil?
        puts "** ERROR: Could not find example #{@example}\n"
        return
      end

      highlight = context.stack do
        wrapped_content = "{% highlight #{lang} %}#{document.content}{% endhighlight %}"
        Liquid::Template.parse(wrapped_content).render!(context)
      end

      icon = Liquid::Template.parse('{% octicon link-external %}').render(context)

      [ '<section class="example-embed">',
        "<h4>#{name}</h4>",
        '<h5>Source</h5>',
        highlight,
        %{<h5><a href="#{document.url}" target="_new">View Result #{icon}</a></h5>},
        '</section>'
      ].join("\n")
    end

    private

    def coerce_documents!
      collection.instance_variable_set(:@filtered_entries, collection.entries.reject do |entry|
        Pathname.new(collection.directory).join(entry).directory?
      end)

      collection.read

      collection.files.reduce(collection.docs) do |memo, file|
        memo << file2doc(file)
      end

      collection.files.slice!(0, collection.files.length)
    end

    def collection
      original = @context.registers[:site].collections['examples']

      @collection ||= Jekyll::Collection.new(@context.registers[:site], original.label)
    end

    def file2doc(file)
      site = @context.registers[:site]

      document = Jekyll::Document.new(file.path, {
        site: site,
        collection: @context.registers[:site].collections['examples']
      }).tap(&:read)

      document.content.tap do |content|
        document.content = content
      end

      document
    end

    Liquid::Template.register_tag('example_embed', Jekyll::ExampleEmbedTag)
  end
end
