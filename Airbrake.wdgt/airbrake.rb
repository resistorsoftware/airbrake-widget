require "open-uri"
require "cgi"
require "rexml/document"
require "uri"
require "net/http"
require "time"

class Airbrake
  def url
    "http://#{subdomain}.airbrake.io/errors.xml?auth_token=#{api_key}&page=#{page}"
  end

  def api_key
    CGI.escape ENV["API_KEY"]
  end

  def subdomain
    CGI.escape ENV["SUBDOMAIN"]
  end

  def page
    [ENV["PAGE"].to_i, 1].max.to_s
  end

  def load
    @load ||= open(url).read rescue nil
  end

  def load!
    @load = nil
    load
  end

  def authorized?
    !(load.to_s =~ /<!DOCTYPE html PUBLIC/m)
  end
end

ab = Airbrake.new

if ab.authorized?
  xml = REXML::Document.new(ab.load)

  if xml.root.nil?
    contents = 'errors'
  elsif xml.elements.to_a("groups/group").size.zero?
    contents = 'no-results'
  else
    contents =  ''

    xml.elements.each("groups/group") { |group|
      message     = group.elements["error-message"].text.to_s.gsub(/</, '&lt;').gsub(/>/, '&gt;')
      count       = group.elements["notices-count"].text.to_i
      most_recent = Time.parse(group.elements["most-recent-notice-at"].text)
      id          = group.elements["id"].text.to_i

      contents << %(
        <div onclick="widget.openURL('http://#{ab.subdomain}.airbrake.io/errors/#{id}?auth_token=#{ab.api_key}');" title="Go to Airbrake" id="exception-#{id}" class="exception">
          <p>
            <strong>#{count}</strong>
            <a>#{message.gsub('::',' :: ')}</a>
            <p class="timeago">
              ~ <abbr title="#{most_recent.utc.strftime("%FT%T%z")}">#{most_recent.strftime("%b %d, %Y ~ %I:%M%p")}</abbr>
            </p>
          </p>
        </div>
      )
    }
  end

  puts contents
end