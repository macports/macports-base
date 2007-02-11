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


require 'fileutils.rb'
require 'stringio'


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
			return "remember <nick> email <address> => remember what port maintainer email <nick> belongs to; " +
					"remember <nick> timezone <timezone> => remember the local timezone for <nick>; " +
					"remember <nick> location <location> => remember the physical location for <nick>"
		  when "forget"
			return "forget <nick> => forget all information for <nick>; " +
				"forget email <nick> => forget email correspondance for <nick>; " +
				"forget timezone <nick> => forget local timezone for <nick>; " +
				"forget location <nick> => forget physical location for <nick>"
		  when "whois"
		  	return "whois <nick> => give a summary of information for <nick>"
		  when "whereis"
		  	return "whereis <nick> => tell what is know about timezone and location of <nick>"
		  else
			return "port (MacPorts) commands: info, maintainer, version, herald, remember, forget, whois, whereis"
		end
	end
	
	def runCmd(cmd, args, input=nil, output=nil, env={})
		# Open pipes for stdin, and stdout
		stdin,   inwrite = IO.pipe
		outread, stdout  = IO.pipe
	
		# Fork the child
		pid = fork {
			# In child
			
			# Change the environment
			ENV.update(env)
	
			# Redirect IO to the pipes
			inwrite.close
			$stdin.reopen(stdin)
			stdin.close
			
			outread.close
			$stdout.reopen(stdout)
			$stderr.reopen(stdout)
			stdout.close
						
			# Execute the command
			exec(cmd, *args)
			# shouldn't return
		}
		
		# Close unneeded pipe-ends in this process
		[stdin, stdout].each { |io| io.close }
		
		# In order to avoid deadlock, invoke a secondary process to write the input
		open("|-", "w+") { |p|
			if (p == nil)
				# In child
				FileUtils.copy_stream(input, inwrite) if !input.nil?
				inwrite.close
			end
		}
		
		# Close remaining write pipe into command
		inwrite.close
	
		# Read the stdout from the command, writing it to output
		FileUtils.copy_stream(outread, output) if !output.nil?
		
		# Close remaining pipe ends
		[outread].each { |io| io.close }
		
		# Collect the return code
		pid, rc = Process.waitpid2(pid)
		rc >>= 8
		
		return rc
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
	
	def rememberEmail(m, params)
		nick = params[:nick]
		email = params[:email]
		@registry["email_#{nick}"] = email
		m.reply "okay, #{nick} is #{email}"
	end
	
	def rememberTimeZone(m, params)
		nick = params[:nick]
		timezone = params[:timezone]
		@registry["timezone_#{nick}"] = timezone
		m.reply "okay, #{nick} is in timezone #{timezone}"
	end
	
	def rememberLocation(m, params)
		nick = params[:nick]
		location = params[:location].join(' ')
		@registry["location_#{nick}"] = location
		m.reply "okay, #{nick} is in #{location}"
	end
	
	def forget(m, params)
		nick = params[:nick]
		@registry.delete("email_#{nick}")
		m.okay
	end

	def forgetEmail(m, params)
		nick = params[:nick]
		@registry.delete("email_#{nick}")
		@registry.delete("timezone_#{nick}")
		@registry.delete("location_#{nick}")
		m.okay
	end

	def forgetTimeZone(m, params)
		nick = params[:nick]
		@registry.delete("timezone_#{nick}")
		m.okay
	end

	def forgetLocation(m, params)
		nick = params[:nick]
		@registry.delete("location_#{nick}")
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
	
	def localTimeInTimeZone(timeZone)
		localTime = nil
		StringIO.open("", "r+") { |o|
			runCmd("/bin/date", "+%a %H:%M %Z", nil, o, { "TZ" => timeZone } )
			o.close_write
			localTime = o.string
		}
		return localTime
	end
	
	def whereisNick(nick)
		location = @registry["location_#{nick}"]
		timeZone = @registry["timezone_#{nick}"]
		
		localTime = nil
		if timeZone
			localTime = localTimeInTimeZone(timeZone)
		end
		
		if location && localTime
			whereis = "is in #{location}; local time is #{localTime}"
		elsif location
			whereis = "is in #{location}"
		elsif localTime
			whereis = "is at local time #{localTime}"
		else
			whereis = nil
		end
	end
	
	def whereis(m, params)
		nick = params[:nick]
		
		where = whereisNick(nick)
		if where
			m.reply "#{nick} #{where}"
		else
			m.reply "I don't know where #{nick} is"
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
				
				msg = nil;
				
				if (portCount == 0)
					msg = "#{nick} is #{email}"
				elsif (portCount <= showMax)
					msg = "#{nick} is #{email} and maintainer of " +
						textEnumeration(somePorts)
				else
					msg = "#{nick} is #{email} and maintainer of " +
						textEnumeration(somePorts) +
						" (of #{portCount} total)"
				end
				
				whereis = whereisNick(nick)
				if whereis
					msg = msg + " and #{whereis}"
				end
				
				@bot.say where, msg
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
plugin.map 'port remember :nick timezone :timezone', :action => 'rememberTimeZone'
plugin.map 'port remember :nick email :email', :action => 'rememberEmail'
plugin.map 'port remember :nick location *location', :action => 'rememberLocation'
plugin.map 'port forget :nick', :action => 'forget'
plugin.map 'port forget :nick email', :action => 'forgetEmail'
plugin.map 'port forget :nick timezone', :action => 'forgetTimeZone'
plugin.map 'port forget :nick location', :action => 'forgetLocation'
plugin.map 'port whois :nick', :action => 'whois'
plugin.map 'port whereis :nick', :action => 'whereis'
