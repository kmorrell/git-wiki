require 'wiki/extensions'
require 'wiki/utils'

module Wiki
  module Helper
    include Utils

    def date(t)
      "<span class=\"date seconds=#{t.to_i}\">#{t.strftime('%d %h %Y %H:%M')}</span>"
    end

    def breadcrumbs(object)
      path = object.respond_to?(:path) ? object.path : ''
      links = ["<a href=\"#{object_path(object, :path => '/root')}\">&radic;&macr; Root</a>"]
      path.split('/').inject('') {|parent,elem|        
        links << "<a href=\"#{object_path(object, :path => parent/elem)}\">#{elem}</a>"
        parent/elem
      }
      
      result = []
      links.each_with_index {|link,i|
        result << "<li class=\"breadcrumb#{i==0 ? ' first' : ''}#{i==links.size-1 ? ' last' : ''}\">#{link}</li>\n"
      }
      result.join("<li class=\"breadcrumb\">/</li>\n")
    end

    def object_path(object, opts = {})
      sha = opts[:sha] || (object && !object.current? ? object.commit : nil) || ''
      sha = sha.sha if sha.respond_to?(:sha)
      path = opts[:path] || object.path
      (path/sha).urlpath + (opts[:output] ? "?output=#{opts[:output]}" : '')
    end

    def action_path(object, action)
      (object.path/action.to_s).urlpath
    end

    def image(alt, name)
      "<img src=\"/images/#{name}.png\" alt=\"#{CGI::escapeHTML alt}\"/>"
    end

    def tab_selected(action)
      action?(action) ? {:class=>'ui-tabs-selected'} : {}
    end

    def menu
      @menu ||= []
      @menu = [@menu] if !@menu.is_a?(Array)
      haml :menu, :layout => false
    end

    def sidebar
      haml :sidebar, :layout => false
    end

    def show_messages
      if @messages
        out = "<ul>\n"
        @messages.each do |msg|
          out += "  <li class=\"#{msg[0]}\">#{msg[1]}</li>\n"
        end
        out += "</ul>\n"
        return out
      end
      ''
    end

    def message(level, messages)
      @messages ||= []
      messages = [messages] if !messages.is_a?(Array)
      messages.each do |msg|
        @messages << [level, msg]
      end
    end

    def action?(name)
      if params[:action]
        params[:action].downcase == name.to_s
      else
        request.path_info.ends_with? '/' + name.to_s
      end
    end

    def fix_punctuation(text)
      safe_require('rubypants') ? RubyPants.new(text).to_html : text
    end
  end
end