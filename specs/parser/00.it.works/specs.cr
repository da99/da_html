
class SPEC_IT_WORKS
  include DA_HTML::Parser

  def self.parse_tag(name : String | Symbol, node : XML::Node)
    case name
    when :doctype!
      allow_tag(node)
    when "html", "head", "title", "body"
      allow_tag(node)
    when "p"
      allow_tag(node)
    when "css", "js"
      allow_tag(node)
      :done

    when "js"
      allow_tag(node)
      :done
    end
  end # === def parse_tag

  def render_tag(tag_name)
    case tag_name
    when "css"
      @io << %(<link href="/main.css" rel="stylesheet">)
    when "js"
      @io << %(<script src="/main.js" type="application/javascript"></script>)
    else
      super
    end
  end # === def render_tag

end # === class Spec_Parser

describe DA_HTML::Parser do
  input_file = "/input.html"
  expected   = File.read("#{__DIR__}/expected.html")

  it "works" do
    actual = SPEC_IT_WORKS.new_from_file(input_file, __DIR__).to_html
    should_eq strip(actual), strip(expected)
  end # === it "#{x.gsub(".", " ")}"
end # === describe
