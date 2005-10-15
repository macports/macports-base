#!/bin/bash
#
# Copyright (c) 2005 Ole Guldberg Jensen <olegb@opendarwin.org>
# Copyright (c) 2005 Dr. Ernie Prabhakar <drernir@opendarwin.org>
# Copyright (c) 2005 Matt Anton <matt@opendarwin.org>
# Copyright (c) 2005 Juan Manuel Palacios <jmpp@opendarwin.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY Eric Melville AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

# check if installation is present
if [ -e /opt/local/var/db/dports/.tclpackage ]; then # set the PATH 
    echo ""
    echo "Checking the PATH variable..."
    echo ""
fi

TMP=`/usr/bin/mktemp /tmp/dp.$$`
/usr/bin/login -f $USER >$TMP <<EOF
  /usr/bin/printenv SHELL
  /usr/bin/printenv PATH
  if test $(/bin/echo $SHELL | /usr/bin/grep bash); then
    bash --login <<EOF2
    /usr/bin/printenv PATH
    exit
EOF2
  fi
  exit
EOF

if grep /opt/local/bin $TMP >/dev/null 2>&1; then
	echo "You have the right PATH - l337!"
    export PATH=/opt/local/bin:$PATH
else
	echo "Setting the PATH for you!"
    USHELL=`basename $SHELL`
    case $USHELL in
      *csh)
		cp /Users/$USER/.cshrc /Users/$USER/.cshrc.dpsaved	# we backup the original
		echo "#" >> /Users/$USER/.cshrc
		echo "# Your .cshrc has been safely renamed to .cshrc.dpsaved" >> /Users/$USER/.cshrc
		echo "# Setting the path for DarwinPorts." >> /Users/$USER/.cshrc
        echo "set path=(/opt/local/bin /opt/local/sbin $path)" >> /Users/$USER/.cshrc
        chown $USER /Users/$USER/.cshrc
        ;;
      bash)
		cp /Users/$USER/.profile /Users/$USER/.profile.dpsaved # we backup the original
		echo "#" >> /Users/$USER/.profile
		echo "# Your .profile has been safely renamed to .profile.dpsaved" >> /Users/$USER/.profile
		echo "# Setting the path for DarwinPorts." >> /Users/$USER/.profile
        echo "export PATH=/opt/local/bin:/opt/local/sbin:$PATH" >> /Users/$USER/.profile
        chown $USER /Users/$USER/.profile
        ;;
      *)
		echo "Strange shell, i am adding changes to your .profile - please check !"
		cp /Users/$USER/.profile /Users/$USER/.profile.dpsaved # we backup the original
		echo "#" >> /Users/$USER/.profile
		echo "# Your .profile has been safely renamed to .profile.dpsaved" >> /Users/$USER/.profile
		echo "# Setting the path for DarwinPorts." >> /Users/$USER/.profile
        echo "export PATH=/opt/local/bin:/opt/local/sbin:$PATH" >> /Users/$USER/.profile
        chown $USER /Users/$USER/.profile
        ;;
    esac

    export PATH=/opt/local/bin:$PATH
fi

# run selfupdate

echo""
echo "Selfupdating The DarwinPorts system ..."
echo ""

port -d selfupdate
if [ $? != 0 ]; then
    echo "An attempt to synchronize your recent DarwinPorts installation with OpenDarwin servers failed, please run 'port -d selfupdate' manually to find out the cause of the error."
    exit
fi

# done !!
echo ""
echo "You have succesfully installed the DarwinPorts system."
echo ""
echo "Launch a terminal and try it out !!"
echo "Read the port manualpage for help."
echo ""
