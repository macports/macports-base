#!/bin/bash

# Set PATH for mp-gsoc
if [[ ! $(echo $PATH | grep gsoc) ]]; then mpswitch; fi

# Set gsocdummy to revision 0
read vernum <<< $(gsocswitchversion | cut -d \  -f 7)
if [[ $vernum = 1 ]]; then
    read vernum <<< $(gsocswitchversion | cut -d \  -f 7)
fi

sudo port uninstall gsocdummy @0.1_0
sudo port uninstall gsocdummy @0.1_1
sudo port install gsocdummy @0.1_0
gsocswitchversion
echo "Ready to upgrade gsocdummy to @0.1_1"


