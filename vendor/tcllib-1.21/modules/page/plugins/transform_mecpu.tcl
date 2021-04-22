# -*- tcl -*- 
# -- $Id: transform_mecpu.tcl,v 1.1 2006/07/01 01:35:21 andreas_kupries Exp $ ---
#
# PAGE plugin - transform - mecpu ~ Translation of grammar to ME cpu instruction set.
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

package require page::compiler::peg::mecpu
package require struct::tree         ; # Data structure.

global usec
global timed
set    timed 0

# ### ### ### ######### ######### #########
## Implementation of exported API

proc page_tlabel {} {
    return {ME cpu Translation}
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
    page_log_info "transform/mecpu/run/"

    if {$timed} {
	set usec [lindex [time {
	    ::struct::tree             ::tree deserialize $data
	    page::compiler::peg::mecpu ::tree
	}] 0] ; #{}
    } else {
	::struct::tree             ::tree deserialize $data
	page::compiler::peg::mecpu ::tree
    }
    set name [::tree get root name]
    set asm  [::tree get root asm]
    ::tree destroy

    page_log_info "transform/mecpu/run/ok"
    return [list $name $asm]
}

# ### ### ### ######### ######### #########
## Internal helper code.

# ### ### ### ######### ######### #########
## Initialization

package provide page::transform::mecpu 0.1
