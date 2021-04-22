# -*- tcl -*- 
# -- $Id: writer_mecpu.tcl,v 1.2 2007/03/21 23:15:53 andreas_kupries Exp $ ---
#
# PAGE plugin - writer - ME cpu ~ Match Engine CPU
#

# ### ### ### ######### ######### #########
## Imported API

# -----------------+--
# page_wdata       | Access to processed input stream.
# -----------------+--
# page_info        | Reporting to the user.
# page_warning     |
# page_error       |
# -----------------+--
# page_log_error   | Reporting of internals.
# page_log_warning |
# page_log_info    |
# -----------------+--

# ### ### ### ######### ######### #########
## Exported API

# -----------------+--
# page_wfeature    | Query for special plugin features page might wish to use.
# page_wtime       | Activate collection of timing statistics.
# page_wgettime    | Return the collected timing statistics.
# page_wlabel      | User readable label for the plugin.
# page_whelp       | Doctools help text for plugin.
# page_woptions    | Options understood by plugin.
# page_wconfigure  | Option (re)configuration.
# page_wrun        | Generate output from data per plugin configuration and hardwiring.
# -----------------+--

# ### ### ### ######### ######### #########
## Requisites

package require page::gen::peg::mecpu

global usec
global timed
set    timed 0

# ### ### ### ######### ######### #########
## Implementation of exported API

proc page_wlabel {} {
    return {ME cpu Assembler}
}

proc page_wfeature {key} {
    return [string eq $key timeable]
}

proc page_wtime {} {
    global timed
    set    timed 1
    return
}

proc page_wgettime {} {
    global  usec
    return $usec
}

proc page_whelp {} {
    return {}
}

proc page_woptions {} {
    return {--package --copyright --template --cmarker}
}

proc page_wconfigure {option value} {
    switch -exact -- $option {
	--package {
	    page::gen::peg::mecpu::package $value
	}
	--copyright {
	    page::gen::peg::mecpu::copyright $value
	}
	--template {
	    page::gen::peg::mecpu::template $value
	}
	--cmarker {
	    page::gen::peg::mecpu::cmarker $value
	}
	default {
	    return -code error "Cannot set value of unknown option \"$option\""
	}
    }
}

proc page_wrun {chan data} {
    global timed usec
    page_log_info "writer/me-cpu/run/"

    if {$timed} {
	set usec [lindex [time {
	    page::gen::peg::mecpu $data $chan
	}] 0] ; #{}
    } else {
	page::gen::peg::mecpu $data $chan
    }
    page_log_info "writer/me-cpu/run/ok"
    return
}

# ### ### ### ######### ######### #########
## Internal helper code.

# ### ### ### ######### ######### #########
## Initialization

package provide page::writer::mecpu 0.1.1
