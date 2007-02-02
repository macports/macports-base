#
#	port.rb
#
#	Plugin to rbot (http://linuxbrit.co.uk/rbot/), an irc bot, to provide
#	services related to MacPorts for the #macports channel on freenode.net.
#
#	By James D. Berry
#
#	$Id$
#


module Shuffle

	def shuffle!
		size.downto(2) do |i|
		r = rand(i)
		tmp = self[i-1]
		self[i-1] = self[r]
		self[r] = tmp
	  end
	  self
	end
	
	def shuffle
		Array.new(self).extend(Shuffle).shuffle!
	end
	
end



class PortPlugin < Plugin

	def help(plugin, topic="")
		case topic
		  when "info"
			return "info <portname> => show info for port <portname>"
		  when "maintainer"
			return "maintainer <portname> => show maintainer of port <portname>"
		  when "version"
			return "version <portname> => show version of port <portname>"
		  when "search"
			return "search <query> => show ports matching <query>"
		  when "herald"
			return "herald enable|disable => enable or disable heralding by port"
		  when "remember"
			return "remember <nick> email <address> => remember what port maintainer email <nick> belongs to"
		  when "forget"
			return "forget <nick> => forget email correspondance for <nick>"
		  else
			return "port (MacPorts) commands: info, maintainer, version, herald, remember, forget, whois"
		end
	end
	
	def callPort(*args)
		Utils.safe_exec("/opt/local/bin/port", *args)
	end
	
	def doPort(m, *args)
		Thread.new do
			text = callPort(*args)
			m.reply text
		end
	end
	
	def info(m, params)
		doPort(m, "info", params[:portname])
	end
	
	def portmaintainer(m, params)
		doPort(m, "info", "--maintainer", params[:portname])
	end
	
	def portversion(m, params)
		doPort(m, "info", "--version", params[:portname])
	end
	
	def portsearch(m, params)
		doPort(m, "search", params[:query])
	end
	
	def herald_enable(m, params)
		@registry['herald_enable'] = true
		m.okay
	end
	
	def herald_disable(m, params)
		@registry['herald_enable'] = false
		m.okay
	end
	
	def remember(m, params)
		nick = params[:nick]
		email = params[:email]
		@registry["email_#{nick}"] = email
		m.reply "okay, #{nick} is #{email}"
	end
	
	def forget(m, params)
		nick = params[:nick]
		@registry.delete("email_#{nick}")
		m.okay
	end

	def whois(m, params)
		nick = params[:nick]
		email = @registry["email_#{nick}"]
		if email
			heraldUser m.replyto, nick
		else
			m.reply "I don't know #{nick}"
		end
	end
	
	def textEnumeration(a)
		sz = a.size
		case sz
			when 0
				return ""
			when 1
				return a[0]
			when 2
				return a.join(' and ')
			else
				return a.slice(0, sz-1).join(', ') + ', and ' + a[sz-1]
		end
	end
	
	def heraldUser(where, nick)
		Thread.new do
			email = @registry["email_#{nick}"]
			if email
				text = callPort("echo", "maintainer:#{email}")
				ports = text.split(/\s+/)
				portCount = ports.size
				showMax = 4
				somePorts = ports.extend(Shuffle).shuffle!.slice(0, showMax)
				
				if (portCount == 0)
					@bot.say where, "#{nick} is #{email}"
				elsif (portCount <= showMax)
					@bot.say where, "#{nick} is #{email} and maintainer of " +
						textEnumeration(somePorts)
				else
					@bot.say where, "#{nick} is #{email} and maintainer of " +
						textEnumeration(somePorts) +
						" (of #{portCount} total)"
				end	
			end
		end
	end
	
	def maybeHerald(where, nick)
		now = Time.new
		minSecondsBetween = 60*10
		
		doHerald = true
		email = @registry["email_#{nick}"]
		if (email)
			lastHerald = @registry["lastherald_#{email}"]
			if (lastHerald)
				secondsAgo = now - lastHerald
				doHerald = secondsAgo > minSecondsBetween
			end
			@registry["lastherald_#{email}"] = now
		end
		
		heraldUser where, nick if doHerald
	end
	
	def join(m)
		maybeHerald m.target, m.sourcenick
	end
	
	def part(m)
		nick = m.sourcenick
		email = @registry["email_#{nick}"]
		@registry["lastherald_#{email}"] = Time.new if email
	end
	
	def nick(m)
  		newnick = m.message
		@bot.channels.each_value { |c|
			if(c.users.has_key?(newnick))
				maybeHerald c.name, newnick
			end
		}
	end

end

plugin = PortPlugin.new
plugin.map 'port info :portname', :action => 'info'
plugin.map 'port maintainer :portname', :action => 'portmaintainer'
plugin.map 'port version :portname', :action => 'portversion'
#plugin.map 'port search :query', :action => 'portsearch'

plugin.map 'port herald enable', :action => 'herald_enable'
plugin.map 'port herald disable', :action => 'herald_disable'
plugin.map 'port remember :nick email :email', :action => 'remember'
plugin.map 'port forget :nick', :action => 'forget'
plugin.map 'port whois :nick', :action => 'whois'
