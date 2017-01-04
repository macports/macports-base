# Main body of code.

puts -nonewline "Loading [info script] ..."

#    $cn connect irc.freenode.net 6667
$cn registerevent 001 "$cn join $channel"

# Register a default action for commands from the server.
$cn registerevent defaultcmd {
    puts "[action] [msg]"
}

# Register a default action for numeric events from the server.
$cn registerevent defaultnumeric {
    puts "[action] XXX [target] XXX [msg]"
}

# Register a default action for events.
$cn registerevent defaultevent {
    puts "[action] XXX [who] XXX [target] XXX [msg]"
}

# Register a default action for PRIVMSG (either public or to a
# channel).

$cn registerevent PRIVMSG {
    puts "[who] says to [target] [msg]"
}

# If you uncomment this, you can change this file and reload it
# without shutting down the network connection.

if {0} {
    $cn registerevent PRIVMSG {
	puts "[who] says to [target] [msg]"
	if { [msg] == "RELOAD" && [target] == $::ircclient::nick } {
	    if [catch {
		::irc::reload
	    } err] {
		puts "Error: $err"
	    }
	    set ::ircclient::RELOAD 1
	}
    }
}

$cn registerevent KICK {
    puts "[who] KICKed [target] : [msg]"
}

puts " done"
