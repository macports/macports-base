#!/usr/bin/tclsh

package require darwinports
dportinit
package require port

proc pindex {portdir} {
        set interp [dportopen $portdir]
        ui_puts [$interp eval {format "%-10s\t%-10s\t%s" $portname $portversion $description}]
	dportclose $interp
}

ui_puts [format "%-10s\t%-10s\t%s" Name Version Description]
port_traverse pindex software

