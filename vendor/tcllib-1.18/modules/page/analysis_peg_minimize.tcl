# -*- tcl -*-
# Transform - Minimize the grammar, through the removal of the
# unreachable and not useful nonterminals (and expressions).

# This package assumes to be used from within a PAGE plugin. It uses
# the API commands listed below. These are identical across the major
# types of PAGE plugins, allowing this package to be used in reader,
# transform, and writer plugins. It cannot be used in a configuration
# plugin, and this makes no sense either.
#
# To ensure that our assumption is ok we require the relevant pseudo
# package setup by the PAGE plugin management code.
#
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
## Requisites

# @mdgen NODEP: page::plugin

package require page::plugin ; # S.a. pseudo-package.
package require page::analysis::peg::reachable
package require page::analysis::peg::realizable

namespace eval ::page::analysis::peg {}

# ### ### ### ######### ######### #########
## API

proc ::page::analysis::peg::minimize {t} {
    page_info {[PEG Minimization]}
    page_log_info ..Reachability  ; ::page::analysis::peg::reachable::remove!
    page_log_info ..Realizability ; ::page::analysis::peg::realizable::remove!

    page_log_info Ok
    return
}

# ### ### ### ######### ######### #########
## Ready

package provide page::analysis::peg::minimize 0.1

