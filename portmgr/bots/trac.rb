#
#	trac.rb
#
#	Plugin to rbot (http://ruby-rbot.org/), an irc bot, to provide
#	services related to MacPorts trac systemfor the #macports channel
#	on freenode.net, created from PortPlugin by James D. Berry
#
#	By Andrea D'Amore
#
#	$Id: $

require 'stringio'

class TracPlugin < Plugin

	def help(plugin, topic="")
		case topic
		  when "ticket"
			return "ticket <ticket no.> => show http link for ticket # <ticket no.>"
		  else
			return "trac commands: ticket"
		end
	end

	def ticket(m, params)
		number = params[:number][/^#?(\d*)$/,1]
		if ( number )
			url = "http://trac.macports.org/ticket/"+number
			m.reply "#{url}"
		else
			m.reply "Use either #1234 or 1234 for ticket number"
		end
	end
	
end

plugin = TracPlugin.new
plugin.map 'ticket :number', :action => 'ticket'
