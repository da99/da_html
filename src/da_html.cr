
require "da_html_escape"
require "da_uri"
require "da"
require "./da_html/Meta"
require "./da_html/Attribute"

module DA
  def strip_each_line(s : String)
    s.strip.lines.map { |x| x.strip }.join('\n')
  end # def
end # === module DA

module DA_HTML
  A_REL_COMMON = {"nofollow", "noopener", "noreferrer"}
  extend self

  def known_tag?(tag_name : Symbol)
    { :html, :link, :meta, :base, :style, :title,
      :body, :address, :article, :aside, :footer, :header,
      :h1, :h2, :h3, :h4, :h5, :h6,
      :hgroup, :nav, :section, :blockquote,
      :dd, :dir, :div, :dl, :dt, :figcaption, :figure,
      :hr, :li, :main, :ol, :p, :pre, :ul, :a, :abbr,
      :b, :bdi, :bdo, :br, :cite, :code, :data,
      :dfn, :em, :i, :kbd, :mark, :q, :rb, :rp,
      :rt, :rtc, :ruby, :s, :samp,
      :small, :span, :strong, :sub, :sup, :time, :tt,
      :u, :var, :wbr,
      :noscript, :script,
      :del, :ins, :caption,
      :col, :colgroup, :table, :tbody, :td,
      :tfoot, :th, :thead, :tr, :button,
      :datalist, :fieldset, :form, :input,
      :label, :legend, :meter, :optgroup, :option,
      :output, :progress, :select, :textarea, :details,
      :dialog, :menu, :menuitem, :summary }.includes? tag_name
  end # def

  def void?(tag_name : Symbol)
    {:area, :base, :br, :col, :command, :embed,
     :hr, :img, :input, :keygen, :link, :meta,
     :param, :source, :track, :wbr}.includes? tag_name
  end # === def

  def prettify(str : String)
    indent = 0
    str.gsub( /\>\<([a-z\/])/ ) { |s, x|
      case x[1]
      when "/"
        indent -= 1
        ">\n#{" " * (indent)}</"
      else
        indent += 1
        ">\n#{" " * indent}<#{x[1]}"
      end
    }
  end # === def pretty_html


  module Class_Base
    def to_html
      page = new
      with page yield
      page.io.to_s
    end # === def

    def to_html(io)
      page = new
      with page yield
      io << page.io
    end # === def
  end # === module Class_Base

  module Base

    getter io : IO::Memory

    def initialize
      @io = IO::Memory.new
    end

    def text(raw : String)
      io << DA_HTML_ESCAPE.escape(raw)
    end # def

    def doctype!
      io << "<!DOCTYPE html>"
    end # def

    def html!
      doctype!
      html lang("en") do
        yield
      end
    end # === def

    def html(*args)
      open_tag(:html, *args)
      yield
      close_tag(:html)
    end # def

    {% for tag in "head".split.map(&.id) %}
      def {{tag}}
        open_tag(:{{tag}})
        yield
        close_tag(:{{tag}})
      end # === def
    {% end %}

    {% for tag in "title".split.map(&.id) %}
      def {{tag}}
        open_tag(:{{tag}})
        result = yield
        text(result) if result.is_a?(String)
        close_tag(:{{tag}})
      end # === def
    {% end %}

    {% for tag in "body p span div".split.map(&.id) %}
      def {{tag}}(*args)
        open_tag(:{{tag}}, *args)
        result = yield
        text(result) if result.is_a?(String)
        close_tag(:{{tag}})
      end # === def
    {% end %}

    def a(*raw)
      attrs  = Deque(Attribute).new
      rel    = Deque(String).new
      href   = nil

      raw.each { |attr|
        case attr
        when String
          attrs.concat Attribute.id_class(attr)
        when Attribute
          k = attr.name
          v = attr.value
          case k
          when :rel
            if v.is_a?(String)
              v.split.each { |x|
                case x
                when "external", "help", "prev", "next", "search", "nofollow", "noopener", "noreferrer"
                  rel.push x
                else
                  raise Attribute::Invalid_Value.new("<a #{k}=#{v.inspect}")
                end
              }
            end

          when :target
            case
            when v.is_a?(String) && {"_self", "_blank", "_parent", "_top"}.includes?(v)
              target = v
              attrs << Attribute.new(k, v)
            else
              raise Attribute::Invalid_Value.new("<a #{k}=#{v.inspect}")
            end

          when :href
            if v.is_a?(String)
              href = DA_URI.clean(v)
              if href.is_a?(String)
                attrs << Attribute.new(k, href)
              end
            end

          else
            raise Attribute::Invalid_Value.new("<a #{k}=#{v.inspect}")

          end # case
        end # case attr
      }

      if !href || href.strip.empty?
        raw_href = raw.find { |x| x.is_a?(Attribute) && x.name == :href }
        if raw_href.is_a?(Attribute)
          raise Attribute::Invalid_Value.new(%[attribute for 'a' tag has an invalid URL: #{raw_href.value.inspect}.])
        else
          raise Attribute::Invalid_Value.new(%[attribute for 'a' tag was not specified.])
        end
      end

      A_REL_COMMON.each { |x|
        if !rel.includes?(x)
          rel.push x
        end
      }
      attrs << Attribute.new(:rel, rel.join(' '))

      tag(:a, attrs) {
        result = yield
        text(result) if result.is_a?(String)
      }
    end # def

    {% for attr in "rel href target lang id class_".split.map(&.id) %}
      def {{attr}}(x : String)
        Attribute.new(:{{attr.gsub(/_+$/, "")}}, x)
      end
    {% end %}

    {% for x in "name content".split.map(&.id) %}
      def {{x}}(s : String)
        DA_HTML::Attribute.new(:name, s)
      end # def
    {% end %}

    def meta_utf8
      tag(
        :meta,
        DA_HTML::Attribute.new(:"http-equiv", "Content-Type"),
        content("text/html; charset=UTF-8")
      )
    end # def

    def <<(x : String)
      io << x
      io
    end # === def

    def attribute(a : Attribute)
      val = a.value
      if val.is_a?(Nil)
        io << ' ' << a.name
      else
        io << ' ' << a.name << '=' << DA_HTML_ESCAPE.escape(a.value.to_s).inspect
      end
    end # def

    def tag(tag_name : Symbol, *args)
      open_tag(tag_name, *args)
      yield
      close_tag(tag_name)
      io
    end # def

    def tag(tag_name : Symbol, *args)
      open_tag(tag_name, *args)
      io
    end # def

    def open_tag(tag_name : Symbol, *args)
      io << '<' << tag_name
      args.each_with_index { |x, i|
        case x
        when String
          Attribute.id_class(x).each { |x|
            attribute x
          }
        when Attribute
          attribute x
        else
          x.each { |x2| attribute x2 }
        end
      }
      io << '>'
      io
    end # def

    def close_tag(tag_name : Symbol)
      io << '<' << '/' << tag_name << '>'
      io
    end # def

    def void_tag(tag_name, *args)
      open_tag(tag_name, *args)
      io
    end # === def

    def link_main_css
      io << %(\n<link href="/main.css" rel="stylesheet">)
    end # def

    def script_main_js
      io << %(\n<script src="/main.js" type="application/javascript"></script>)
    end # def

    {% for x in "nofollow noreferrer noopener".split.map(&.id) %}
      def {{x}}
        Attribute.new(:{{x}})
      end
    {% end %}

    def to_s(io_)
      io_ << @io
    end
  end # === module Base

  struct Page
    include Base
    include Meta
  end # === struct Page

  def to_html(io)
    page = Page.new
    with page yield
    io << page.io
  end # === def

  def to_html
    page = Page.new
    with page yield
    page.io.to_s
  end # === def

end # === module DA_HTML


