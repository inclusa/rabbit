# Copyright (C) 2012  Kouhei Sutou <kou@cozmixng.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

require "yaml"

require "rabbit/console"
require "rabbit/author-configuration"
require "rabbit/slide-configuration"
require "rabbit/path-manipulatable"

module Rabbit
  module Command
    class RabbitSlide
      include GetText
      include PathManipulatable

      class << self
        def run(*arguments)
          new.run(arguments)
        end
      end

      def initialize
        @title = nil
        @allotted_time = nil
        @slide_conf = nil
        @author_conf = nil
        @logger = nil
      end

      def run(arguments)
        @options, @logger = parse_command_line_arguments(arguments)

        validate
        unless @validation_errors.empty?
          messages = (@validation_errors + [_("See --help for example")])
          @logger.error(messages.join("\n"))
          return false
        end

        generate
        @author_conf.save
        true
      end

      private
      def parse_command_line_arguments(arguments)
        Rabbit::Console.parse!(ARGV) do |parser, options|
          @logger = options.default_logger
          @author_conf = AuthorConfiguration.new(@logger)
          @author_conf.load
          @slide_conf = SlideConfiguration.new(@logger)
          @slide_conf.author = @author_conf

          format = _("Usage: %s new [options]\n" \
                     " e.g.: %s new \\\n" \
                     "          --id rubykaigi2012 \\\n" \
                     "          --base-name rabbit-introduction \\\n" \
                     "          --markup-language rd \\\n" \
                     "          --name \"Kouhei Sutou\" \\\n" \
                     "          --email kou@cozmixng.org \\\n" \
                     "          --rubygems-user kou \\\n" \
                     "          --slideshare-user kou \\\n" \
                     "          --speaker-deck-user kou")

          program = File.basename($0, ".*")
          parser.banner = format % [program, program]

          parser.separator("")

          parser.separator(_("Slide information"))

          parser.on("--id=ID",
                    _("Slide ID"),
                    _("(e.g.: %s)") % "--id=rubykaigi2012",
                    _("(must)")) do |id|
            @slide_conf.id = id
          end

          messages = [
            _("Base name for the slide source file and generated PDF file"),
            _("(e.g.: %s)") % "--base-name=rabbit-introduction",
            _("(must)"),
          ]
          parser.on("--base-name=NAME",
                    *messages) do |base_name|
            @slide_conf.base_name = base_name
          end

          available_markup_languages = [:rd, :hiki, :markdown]
          label = "[" + available_markup_languages.join(", ") + "]"
          messages = [
            _("Markup language for the new slide"),
            _("(e.g.: %s)") % "--markup-language=rd",
            _("(available markup languages: %s)") % label,
          ]
          if @author_conf.markup_language
            messages << _("(default: %s)") % @author_conf.markup_language
          end
          messages << _("(optional)")
          parser.on("--markup-language=LANGUAGE", available_markup_languages,
                    *messages) do |language|
            @author_conf.markup_language = language
          end

          parser.on("--title=TITLE",
                    _("Title of the new slide"),
                    _("(e.g.: %s)") % _("--title=\"Rabbit Introduction\""),
                    _("(optional)")) do |title|
            @title = title
          end

          parser.on("--tags=TAG,TAG,...",
                    Array,
                    _("Tags of the new slide"),
                    _("(e.g.: %s)") % "--tags=rabbit,presentation,ruby",
                 _("(optional)")) do |tags|
            @slide_conf.tags.concat(tags)
          end

          parser.on("--allotted-time=TIME",
                    _("Allotted time in presentaion"),
                    _("(e.g.: %s)") % "--allotted-time=5m",
                    _("(optional)")) do |allotted_time|
            @allotted_time = allotted_time
          end

          parser.on("--presentation-date=DATE",
                    _("Presentation date with the new slide"),
                    _("(e.g.: %s)") % "--presentation-date=2012/06/29",
                    _("(optional)")) do |date|
            @slide_conf.presentation_date = date
          end

          parser.separator(_("Your information"))

          messages = [
            _("Author name of the new slide"),
            _("(e.g.: %s)") % "--name=\"Kouhei Sutou\"",
          ]
          if @author_conf.name
            messages << _("(default: %s)") % @author_conf.name
          end
          messages << _("(optional)")
          parser.on("--name=NAME",
                    *messages) do |name|
            @author_conf.name = name
          end

          messages = [
            _("Author e-mail of the new slide"),
            _("(e.g.: %s)") % "--email=kou@cozmixng.org",
          ]
          if @author_conf.email
            messages << _("(default: %s)") % @author_conf.email
          end
          messages << _("(optional)")
          parser.on("--email=EMAIL",
                    *messages) do |email|
            @author_conf.email = email
          end

          messages = [
            _("Account for %s") % "RubyGems.org",
            _("It is used to publish your slide to %s") % "RubyGems.org",
            _("(e.g.: %s)") % "--rubygems-user=kou",
          ]
          if @author_conf.rubygems_user
            messages << _("(default: %s)") % @author_conf.rubygems_user
          end
          messages << _("(optional)")
          parser.on("--rubygems-user=USER",
                    *messages) do |user|
            @author_conf.rubygems_user = user
          end

          messages = [
            _("Account for %s") % "SlideShare",
            _("It is used to publish your slide to %s") % "SlideShare",
            _("(e.g.: %s)") % "--slideshare-user=kou",
          ]
          if @author_conf.slideshare_user
            messages << _("(default: %s)") % @author_conf.slideshare_user
          end
          messages << _("(optional)")
          parser.on("--slideshare-user=USER",
                    *messages) do |user|
            @author_conf.slideshare_user = user
          end

          messages = [
            _("Account for %s") % "Speaker Deck",
            _("It is used to publish your slide to %s") % "Speaker Deck",
            _("(e.g.: %s)") % "--speaker-deck-user=kou",
          ]
          if @author_conf.speaker_deck_user
            messages << _("(default: %s)") % @author_conf.speaker_deck_user
          end
          messages << _("(optional)")
          parser.on("--speaker-deck-user=USER",
                    *messages) do |user|
            @author_conf.speaker_deck_user = user
          end
        end
      end

      def validate
        @validation_errors = []
        validate_command
        validate_id
        validate_base_name
      end

      def validate_command
        if @options.rest.empty?
          @options.rest << "new"
        end
        if @options.rest.size != 1
          message = _("too many commands: %s") % @options.rest.inspect
          @validation_errors << message
        end
        @command = @options.rest[0]
        if @command != "new"
          format = _("invalid command: <%s>: available commands: %s")
          message = format % [@command, "[new]"]
          @validation_errors << message
        end
      end

      def validate_id
        if @slide_conf.id.nil?
          @validation_errors << (_("%s is missing") % "--id")
        end
      end

      def validate_base_name
        if @slide_conf.base_name.nil?
          @validation_errors << (_("%s is missing") % "--base-name")
        end
      end

      def generate
        generate_directory
        generate_dot_rabbit
        generate_slide_configuration
        generate_readme
        generate_rakefile
        generate_slide
      end

      def generate_directory
        create_directory(@slide_conf.id)
      end

      def generate_dot_rabbit
        create_file(".rabbit") do |dot_rabbit|
          options = []
          if @author_conf.markup_language.nil? and @allotted_time
            options << "--allotted-time #{@allotted_time}"
          end
          options << slide_path
          dot_rabbit.puts(options.join("\n"))
        end
      end

      def generate_slide_configuration
        @slide_conf.save(@slide_conf.id)
      end

      def generate_readme
        create_file("README.#{readme_extension}") do |readme|
          readme.puts(readme_content)
        end
      end

      def readme_content
        markup_language = @author_conf.markup_language || :rd
        syntax = markup_syntax(markup_language)

        content = ""
        title = @title || _("TODO: SLIDE TITLE")
        content << (syntax[:heading1] % {:title => title})
        content << "\n\n"
        content << _("TODO: SLIDE DESCRIPTION")
        content << "\n\n"

        content << (syntax[:heading2] % {:title => _("For author")})
        content << "\n\n"
        content << (syntax[:heading3] % {:title => _("Show")})
        content << "\n\n"
        content << (syntax[:preformatted_line] % {:content => "rake"})
        content << "\n\n"
        content << (syntax[:heading3] % {:title => _("Publish")})
        content << "\n\n"
        content << (syntax[:preformatted_line] % {:content => "rake publish"})
        content << "\n\n"

        content << (syntax[:heading2] % {:title => _("For viewers")})
        content << "\n\n"
        content << (syntax[:heading3] % {:title => _("Install")})
        content << "\n\n"
        install_command = "gem install #{@slide_conf.gem_name}"
        content << (syntax[:preformatted_line] % {:content => install_command})
        content << "\n\n"
        content << (syntax[:heading3] % {:title => _("Show")})
        content << "\n\n"
        show_command = "rabbit #{@slide_conf.gem_name}.gem"
        content << (syntax[:preformatted_line] % {:content => show_command})
        content << "\n\n"
      end

      def generate_rakefile
        create_file("Rakefile") do |rakefile|
          rakefile.puts(<<-EOR)
require "rabbit/task/slide"

# Edit ./config.yaml to customize meta data

Rabbit::Task::Slide.new do |task|
  # task.spec.licenses = ["CC BY-SA 3.0"]
  # task.spec.files += Dir.glob("doc/**/*.*")
  # task.spec.files -= Dir.glob("private/**/*.*")
  # task.spec.add_runtime_dependency("YOUR THEME")
end
EOR
        end
      end

      def generate_slide
        source = slide_source
        return if source.nil?
        create_file(slide_path) do |slide|
          slide.puts(source)
        end
      end

      def slide_path
        "#{@slide_conf.base_name}.#{slide_source_extension}"
      end

      def slide_source_extension
        case @author_conf.markup_language
        when :rd
          "rab"
        when :hiki
          "hiki"
        when :markdown
          "md"
        else
          "pdf"
        end
      end

      def readme_extension
        case @author_conf.markup_language
        when :rd
          "rd"
        when :hiki
          "hiki"
        when :markdown
          "md"
        else
          "rd"
        end
      end

      def slide_source
        syntax = slide_source_syntax
        return nil if syntax.nil?

        source = ""
        slide_source_title(source, syntax, @title || _("TITLE"))
        slide_source_metadata(source, syntax)
        slide_source_title(source, syntax, _("FIRST SLIDE"))
        slide_source_items(source, syntax)
        slide_source_title(source, syntax, _("SECOND SLIDE"))
        slide_source_image(source, syntax)
      end

      def slide_source_title(source, syntax, title)
        source << (syntax[:heading1] % {:title => _("TITLE")})
        source << "\n\n"
      end

      def slide_source_metadata(source, syntax)
        presentation_date = @slide_conf.presentation_date
        slide_metadata = [
          ["subtitle",       nil,                _("SUBTITLE")],
          ["author",         @author_conf.name,  _("AUTHOR")],
          ["institution",    nil,                _("INSTITUTION")],
          ["content-source", nil,                _("EVENT NAME")],
          ["date",           presentation_date,  Time.now.strftime("%Y/%m/%d")],
          ["allotted-time",  @allotted_time,     "5m"],
          ["theme",          nil,                "default"],
        ]
        slide_metadata.each do |key, value, default_value|
          data = {:item => key, :description => value || default_value}
          item = syntax[:definition_list_item] % data
          item << "\n"
          if value
            source << item
          else
            item.each_line do |line|
              source << (syntax[:comment] % {:content => line})
            end
          end
        end
        source << "\n\n"
      end

      def slide_source_items(source, syntax)
        1.upto(3) do |i|
          source << syntax[:unorderd_list_item] % {:item => _("ITEM %d") % i}
          source << "\n"
        end
        source << "\n"
      end

      def slide_source_image(source, syntax)
        lavie = "https://raw.github.com/shockers/rabbit/master/sample/lavie.png"
        data = {
          :src => lavie,
          :relative_height => 100,
        }
        source << syntax[:image] % data
        source << "\n"
      end

      def slide_source_syntax
        markup_syntax(@author_conf.markup_language)
      end

      def markup_syntax(markup_language)
        case markup_language
        when :rd
          {
            :heading1             => "= %{title}",
            :heading2             => "== %{title}",
            :heading3             => "=== %{title}",
            :definition_list_item => ": %{item}\n   %{description}",
            :unorderd_list_item   => "  * %{item}",
            :image                =>
              "  # image\n" +
              "  # src = %{src}\n" +
              "  # relative_height = %{relative_height}",
            :preformatted_line    => "  %{content}",
            :comment              => "# %{content}",
          }
        when :hiki
          {
            :heading1             => "! %{title}",
            :heading2             => "!! %{title}",
            :heading3             => "!!! %{title}",
            :definition_list_item => ":%{item}:%{description}",
            :unorderd_list_item   => "* %{item}",
            :image                =>
              "{{image(\"%{src}\",\n" +
              "        {\n" +
              "          :relative_height => %{relative_height},\n" +
              "        })}}",
            :preformatted_line    => " %{content}",
            :comment              => "// %{content}",
          }
        when :markdown
          {
            :heading1             => "# %{title}",
            :heading2             => "## %{title}",
            :heading3             => "### %{title}",
            :definition_list_item => "%{item}\n   %{description}",
            :unorderd_list_item   => "* %{item}",
            :image                =>
              "![](%{src}){:relative_height='%{relative_height}'}",
            :preformatted_line    => "    %{content}",
            :comment              => "",
          }
        else
          nil
        end
      end

      def create_file(path, &block)
        super(File.join(@slide_conf.id, path), &block)
      end
    end
  end
end
