# -*- tcl -*- 
# -- $Id: reader_ser.tcl,v 1.1 2005/09/28 04:51:22 andreas_kupries Exp $ ---
#
# PAGE plugin - reader - SER ~ Serialized PEG Container
#

# ### ### ### ######### ######### #########
## Imported API

# -----------------+--
# page_read        | Access to the input stream.
# page_read_done   |
# page_eof         |
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
# page_rfeature    | Query for special plugin features page might wish to use.
# page_rtime       | Activate collection of timing statistics.
# page_rgettime    | Return the collected timing statistics.
# page_rlabel      | User readable label for the plugin.
# page_rhelp       | Doctools help text for plugin.
# page_roptions    | Options understood by plugin.
# page_rconfigure  | Option (re)configuration.
# page_rdata       | External access to processed input stream.
# page_rrun        | Process input stream per plugin configuration and hardwiring.
# -----------------+--

# ### ### ### ######### ######### #########
## Requisites

package require struct::tree         ; # Data structure.
package require page::parse::pegser

global usec
global timed
set    timed 0

# ### ### ### ######### ######### #########
## Implementation of exported API

proc page_rlabel {} {
    return {Serialized PEG Container}
}

proc page_rfeature {key} {
    return [string eq $key timeable]
}

proc page_rtime {} {
    global timed
    set    timed 1
    return
}

proc page_rgettime {} {
    global  usec
    return $usec
}

proc page_rhelp {} {
    return {}
}

proc page_roptions {} {
    return {}
}

proc page_rconfigure {option value} {
    return -code error "Cannot set value of unknown option \"$option\""
}

## proc page_rdata {} {}
## Created in 'Initialize'

proc page_rrun {} {
    global timed usec
    page_log_info "reader/ser/run/parse"

    struct::tree                    ::tree

    if {$timed} {
	set usec [lindex [time {
	    page::parse::pegser [page_read] ::tree
	}] 0] ; #{}
    } else {
	page::parse::pegser [page_read] ::tree
    }
    page_read_done

    set ast [::tree serialize]
    ::tree destroy

    page_log_info "reader/ser/run/ok"
    return $ast
}

# ### ### ### ######### ######### #########
## Internal helper code.

# ### ### ### ######### ######### #########
## Initialization

package provide page::reader::ser 0.1
