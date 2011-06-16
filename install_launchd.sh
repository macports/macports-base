#!/bin/sh

# 

# Where the generated plist should be written
PLIST=/Library/LaunchAgents/org.macports.stats.plist

die () {
    echo >&2 "$@"
    exit 1
}

# Make sure exactly 2 arguments are provided
[ "$#" -eq 2 ] || die "exactly two arguments required"

# $1 must be the path to the script launchd will execute
SCRIPT=$1

# $2 is the path to the MacPorts configuration file
CONFIG=$2

# Make sure the script argument is executable
if [ ! -x "$SCRIPT" ]; then
   	die "$SCRIPT is not a valid executable"
fi

# Make sure the config file exists
if [ ! -f "$CONFIG" ]; then
   	die "$CONFIG does not exist"
fi

# Determine the day and time that launchd should run the script
setup_times() {
    # Get hardware uuid - Hardware UUID: UUID
    huuid=`system_profiler SPHardwareDataType | grep "Hardware UUID"`
    
    # Strip out Hardware UUID:   
    huuid=`echo $huuid | awk '/Hardware UUID/ {print $3;}'`
    
    # Strip out '-' characters
    huuid=`echo $huuid | tr -d -`
    
    # Weekday is hardware uuid mod 7
    weekday=`echo $huuid % 7 | bc`
    
    # Use current hours and minute
    hour=`date '+%H'`
    minute=`date '+%M'`
}

# Generate the launchd plist that executes 'port stats submit'
# Outputs to the file $plist
generate_plist() {
    setup_times
	cat <<-EOF > $PLIST
		<?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
         <dict>
          <key>Label</key>
          <string>org.macports.stats</string>
          <key>ProgramArguments</key>
          <array>
             <string>$SCRIPT</string>
             <string>$CONFIG</string>
          </array>
          <key>StartCalendarInterval</key>
          <dict>
            <key>Weekday</key>
            <integer>$weekday</integer>
            <key>Hour</key>
            <integer>$hour</integer>
            <key>Minute</key>
            <integer>$minute</integer>
          </dict>
         </dict>
        </plist>
	EOF
}

# Install the plist using launchctl
install_plist() {
	launchctl load -w -F $PLIST
}

# Generate and install the plist
generate_plist
install_plist


