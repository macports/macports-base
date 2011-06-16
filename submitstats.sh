#!/bin/sh

# This script calls port stats submit only if a user is participating.
# This script should not be called directly - It will be run by launchd

# It takes one argument - the path to the MacPorts configuration file
# It checks that configuration file for the value of 'stats_participate'
# It runs 'port stats submit' only if 'stats_participate' is set to 'yes'

configfile=$1

die () {
    echo >&2 "$@"
    exit 1
}

# Make sure the config file exists
if [ ! -f "$configfile" ]; then
   	die "$CONFIG does not exist"
fi

# Read configfile and see if stats_participate is set to yes
is_participating() {
	# An example line is "stats_participate yes"
	line=$(grep "stats_participate" $configfile)
	participating=$(awk '{print $2}' <<< $line)
	if [ "$participating" == "yes" ]; then
		return 0 # Return true - user is participating
	else  
		return 1 # Return false
	fi
}

# Run the command if the user is participating
if is_participating ; then
	port stats submit > /dev/null
fi

