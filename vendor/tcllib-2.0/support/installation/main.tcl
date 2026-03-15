# -*- tcl -*-
# Entrypoint for starkit and -pack based distributions

# Delegate to the installer application
source [file join [file dirname [info script]] installer.tcl]
