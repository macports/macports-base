# -*- tcl -*- 
# -- $Id: transform_reachable.tcl,v 1.1 2005/09/28 04:51:22 andreas_kupries Exp $ ---
#
# PAGE plugin - transform - reachable ~ Reachability Analysis
#

# ### ### ### ######### ######### #########
## Imported API

# -----------------+--
# page_tdata       | Access to processed input stream.
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
# page_tfeature    | Query for special plugin features page might wish to use.
# page_ttime       | Activate collection of timing statistics.
# page_tgettime    | Return the collected timing statistics.
# page_tlabel      | User readable label for the plugin.
# page_thelp       | Doctools help text for plugin.
# page_toptions    | Options understood by plugin.
# page_tconfigure  | Option (re)configuration.
# page_trun        | Transform input data per plugin configuration and hardwiring.
# -----------------+--

# ### ### ### ######### ######### #########
## Requisites

package require page::analysis::peg::reachable
package require struct::tree         ; # Data structure.

global usec
global timed
set    timed 0

# ### ### ### ######### ######### #########
## Implementation of exported API

proc page_tlabel {} {
    return Reachability
}

proc page_tfeature {key} {
    return [string eq $key timeable]
}

proc page_ttime {} {
    global timed
    set    timed 1
    return
}

proc page_tgettime {} {
    global  usec
    return $usec
}

proc page_thelp {} {
    return {}
}

proc page_toptions {} {
    return {}
}

proc page_tconfigure {option value} {
    return -code error "Cannot set value of unknown option \"$option\""
}

proc page_trun {data} {
    global timed usec
    page_log_info "transform/reachable/run/"

    if {$timed} {
	set usec [lindex [time {
	    ::struct::tree          ::tree deserialize $data
	    ::page::analysis::peg::reachable::remove! ::tree
	}] 0] ; #{}
    } else {
	::struct::tree          ::tree deserialize $data
	::page::analysis::peg::reachable::remove! ::tree
    }

    set data [::tree serialize]
    ::tree destroy

    page_log_info "transform/reachable/run/ok"
    return $data
}

# ### ### ### ######### ######### #########
## Internal helper code.

# ### ### ### ######### ######### #########
## Initialization

package provide page::transform::reachable 0.1
