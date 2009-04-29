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
		  when "faq"
			return "faq [help] => show FAQs' URL or help"
		  when "guide"
			return "guide [help] => show The Guide's URL or help. Don't Panic."		 
		  else
			return "trac module provides: !ticket, !faq, !guide"
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

	def faq(m, params)
		if ( params[:parm] )
			m.reply "Just type !faq for now"
		else
			m.reply "FAQs are at: http://trac.macports.org/wiki/FAQ"
		end
	end

	def guide(m, params)
		if ( params[:parm] == "chunked" )
			m.reply "http://guide.macports.org/chunked/index.html"
		elsif ( params[:parm] != "" )
			m.reply "Just type !faq for now"
		else
			m.reply "FAQs are at: http://trac.macports.org/wiki/FAQ"
		end
	end
	
end

plugin = TracPlugin.new
plugin.map 'ticket :number', :action => 'ticket'
plugin.map 'faq :parm', :action => 'faq'
plugin.map 'guide :parm', :action => 'guide'