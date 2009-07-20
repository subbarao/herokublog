require 'rubygems'
require 'maruku'
class Post < Sequel::Model

  set_primary_key :id

  def url
    d = created_at
    "/past/#{d.year}/#{d.month}/#{d.day}/#{slug}/"
  end

  def full_url
    Blog.url_base.gsub(/\/$/, '') + url
  end

  def body_html
    to_html(body)
  end

  def summary
    if body.match(/(.{300}.*?\n)/m) && (/<pre([^<]+)<\/pre>/m).match(body)
      (/<pre([^<]+)<\/pre>/m).match(body).pre_match
    elsif body.match(/(.{300}.*?\n)/m)
      body.match(/(.{300}.*?\n)/m).to_s
    else
      body
    end
  end

  def summary_html
    @summary ||= summary
    to_html(@summary)
  end

  def more?
    @more ||= body.match(/.{300}.*?\n(.*)/m)
    @more
  end

  def linked_tags
    (tags||'').split.inject([]) do |accum, tag|
      accum << "<a href=\"/past/tags/#{tag}\">#{tag}</a>"
    end.join(" ")
  end

  def self.make_slug(title)
    title.downcase.gsub(/ /, '_').gsub(/[^a-z0-9_]/, '').squeeze('_')
  end

  ########

  def to_html(markdown)
    Maruku.new(markdown).to_html
  end

  def split_content(string)
    parts = string.gsub(/\r/, '').split("\n\n")
    show = []
    hide = []
    parts.each do |part|
      if show.join.length < 100
        show << part
      else
        hide << part
      end
    end
    [ to_html(show.join("\n\n")), hide.size > 0 ]
  end
end
