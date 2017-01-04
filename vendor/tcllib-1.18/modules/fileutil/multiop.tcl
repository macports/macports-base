# ### ### ### ######### ######### #########
##
# (c) 2007-2008 Andreas Kupries.

# DSL allowing the easy specification of multi-file copy and/or move
# and/or deletion operations. Alternate names would be scatter/gather
# processor, or maybe even assembler.

# Examples:
# (1) copy
#     into [installdir_of tls]
#     from c:/TDK/PrivateOpenSSL/bin
#     the  *.dll
#
# (2) move
#     from /sources
#     into /scratch
#     the  *
#     but not *.html
#  (Alternatively: except for *.html)
#
# (3) into /scratch
#     from /sources
#     move
#     as   pkgIndex.tcl
#     the  index
#
# (4) in /scratch
#     remove
#     the *.txt

# The language is derived from the parts of TclApp's option language
# dealing with files and their locations, yet not identical. In parts
# simplified, in parts more capable, keyword names were changed
# throughout.

# Language commands

# From the examples
#
# into        DIR           : Specify destination directory.
# in          DIR           : See 'into'.
# from        DIR           : Specify source directory.
# the         PATTERN (...) : Specify files to operate on.
# but not     PATTERN       : Specify exceptions to 'the'.
# but exclude PATTERN       : Specify exceptions to 'the'.
# except for  PATTERN       : See 'but not'.
# as          NAME          : New name for file.
# move                      : Move files.
# copy                      : Copy files.
# remove                    : Delete files.
#
# Furthermore
#
# reset     : Force to defaults.
# cd    DIR : Change destination to subdirectory.
# up        : Change destination to parent directory.
# (         : Save a copy of the current state.
# )         : Restore last saved state and make it current.

# The main active element is the command 'the'. In other words, this
# command not only specifies the files to operate on, but also
# executes the operation as defined in the current state. All other
# commands modify the state to set the operation up, and nothing
# else. To allow for a more natural syntax the active command also
# looks ahead for the commands 'as', 'but', and 'except', and executes
# them, like qualifiers, so that they take effect as if they had been
# written before. The command 'but' and 'except use identical
# constructions to handle their qualifiers, i.e. 'not' and 'for'.

# Note that the fact that most commands just modify the state allows
# us to use more off forms as specifications instead of just natural
# language sentences For example the example 2 can re-arranged into:
#
# (5) from /sources
#     into /scratch
#     but not *.html
#     move
#     the  *
#
# and the result is still a valid specification.

# Further note that the information collected by 'but', 'except', and
# 'as' is automatically reset after the associated 'the' was
# executed. However no other state is reset in that manner, allowing
# the user to avoid repetitions of unchanging information. Lets us for
# example merge the examples 2 and 3. The trivial merge is:

# (6) move
#     into /scratch
#     from /sources
#     the  *
#     but not *.html not index
#     move
#     into /scratch
#     from /sources
#     the  index
#     as   pkgIndex.tcl
#
# With less repetitions
#
# (7) move
#     into /scratch
#     from /sources
#     the  *
#     but not *.html not index
#     the  index
#     as   pkgIndex.tcl

# I have not yet managed to find a suitable syntax to specify when to
# add a new extension to the moved/copied files, or have to strip all
# extensions, a specific extension, or even replace extensions.

# Other possibilities to muse about: Load the patterns for 'not'/'for'
# from a file ... Actually, load the whole exceptions from a file,
# with its contents a proper interpretable word list. Which makes it
# general processing of include files.

# ### ### ### ######### ######### #########
## Requisites

# This processor uses the 'wip' word list interpreter as its
# foundation.

package require fileutil      ; # File testing
package require snit          ; # OO support
package require struct::stack ; # Context stack
package require wip           ; # DSL execution core

# ### ### ### ######### ######### #########
## API & Implementation

snit::type ::fileutil::multi::op {
    # ### ### ### ######### ######### #########
    ## API

    constructor {args} {} ; # create processor

    # ### ### ### ######### ######### #########
    ## API - Implementation.

    constructor {args} {
	install stack using struct::stack ${selfns}::stack
	$self wip_setup

	# Mapping dsl commands to methods.
	defdva \
	    reset  Reset	(    Push	)       Pop	\
	    into   Into		in   Into	from    From	\
	    cd     ChDir	up   ChUp	as      As	\
	    move   Move		copy Copy	remove  Remove	\
	    but    But		not  Exclude	the     The	\
	    except Except	for  Exclude    exclude Exclude \
	    to     Into         ->   Save       the-set TheSet  \
	    recursive Recursive recursively Recursive           \
	    for-win     ForWindows   for-unix   ForUnix         \
	    for-windows ForWindows   expand     Expand          \
	    invoke Invoke strict Strict !strict NotStrict \
	    files  Files  links  Links  all Everything    \
	    dirs   Directories directories Directories    \
	    state? QueryState from? QueryFrom into? QueryInto \
	    excluded? QueryExcluded as? QueryAs type? QueryType \
	    recursive? QueryRecursive operation? QueryOperation \
	    strict? QueryStrict !recursive NotRecursive

	$self Reset
	runl $args
	return
    }

    destructor {
	$mywip destroy
	return
    }

    method do {args} {
	return [runl $args]
    }

    # ### ### ### ######### ######### #########
    ## DSL Implementation
    wip::dsl

    # General reset of processor state
    method Reset {} {
	$stack clear
	set base     ""
	set alias    ""
	set op       ""
	set recursive 0 
	set src      ""
	set excl     ""
	set types    {}
	set strict   0
	return
    }

    # Stack manipulation
    method Push {} {
	$stack push [list $base $alias $op $opcmd $recursive $src $excl $types $strict]
	return
    }

    method Pop {} {
	if {![$stack size]} {
	    return -code error {Stack underflow}
	}
	foreach {base alias op opcmd recursive src excl types strict} [$stack pop] break
	return
    }

    # Destination directory
    method Into {dir} {
	if {$dir eq ""} {set dir [pwd]}
	if {$strict && ![fileutil::test $dir edr msg {Destination directory}]} {
	    return -code error $msg
	}
	set base $dir
	return
    }

    method ChDir {dir} { $self Into [file join    $base $dir] ; return }
    method ChUp  {}    { $self Into [file dirname $base]      ; return }

    # Detail
    method As {fname} {
	set alias [ForceRelative $fname]
	return
    }

    # Operations
    method Move   {} { set op move   ; return }
    method Copy   {} { set op copy   ; return }
    method Remove {} { set op remove ; return }
    method Expand {} { set op expand ; return }

    method Invoke {cmdprefix} {
	set op    invoke
	set opcmd $cmdprefix
	return
    }

    # Operation qualifier
    method Recursive    {} { set recursive 1 ; return }
    method NotRecursive {} { set recursive 0 ; return }

    # Source directory
    method From {dir} {
	if {$dir eq ""} {set dir [pwd]}
	if {![fileutil::test $dir edr msg {Source directory}]} {
	    return -code error $msg
	}
	set src $dir
	return
    }

    # Exceptions
    method But    {} { run_next_while {not exclude} ; return }
    method Except {} { run_next_while {for}         ; return }

    method Exclude {pattern} {
	lappend excl $pattern
	return
    }

    # Define the files to operate on, and perform the operation.
    method The {pattern} {
	run_next_while {as but except exclude from into in to files dirs directories links all}

	switch -exact -- $op {
	    invoke {Invoke [Resolve [Remember [Exclude [Expand $src  $pattern]]]]}
	    move   {Move   [Resolve [Remember [Exclude [Expand $src  $pattern]]]]}
	    copy   {Copy   [Resolve [Remember [Exclude [Expand $src  $pattern]]]]}
	    remove {Remove          [Remember [Exclude [Expand $base $pattern]]] }
	    expand {                 Remember [Exclude [Expand $base $pattern]]  }
	}

	# Reset the per-pattern flags of the resolution context back
	# to their defaults, for the next pattern.

	set alias    {}
	set excl     {}
	set recursive 0
	return
    }

    # Like 'The' above, except that the fileset is taken from the
    # specified variable. Semi-complementary to 'Save' below.
    # Exclusion data and recursion info do not apply for this, this is
    # already implicitly covered by the set, when it was generated.

    method TheSet {varname} {
	# See 'Save' for the levels we jump here.
	upvar 5 $varname var

	run_next_while {as from into in to}

	switch -exact -- $op {
	    invoke {Invoke [Resolve $var]}
	    move   {Move   [Resolve $var]}
	    copy   {Copy   [Resolve $var]}
	    remove {Remove          $var }
	    expand {
		return -code error "Expansion does not make sense\
                                    when we already have a set of files."
	    }
	}

	# Reset the per-pattern flags of the resolution context back
	# to their defaults, for the next pattern.

	set alias    {}
	return
    }

    # Save the last expansion result to a variable for use by future commands.

    method Save {varname} {
	# Levels to jump. Brittle.
	# 5: Caller
	# 4:   object do ...
	# 3:     runl
	# 2:       wip::runl
	# 1:         run_next
	# 0: Here
	upvar 5 $varname v
	set v $lastexpansion
	return
    }

    # Platform conditionals ...

    method ForUnix {} {
	global tcl_platform
	if {$tcl_platform(platform) eq "unix"} return
	# Kill the remaining code. This effectively aborts processing.
	replacel {}
	return
    }

    method ForWindows {} {
	global tcl_platform
	if {$tcl_platform(platform) eq "windows"} return
	# Kill the remaining code. This effectively aborts processing.
	replacel {}
	return
    }

    # Strictness

    method Strict {} {
	set strict 1
	return
    }

    method NotStrict {} {
	set strict 0
	return
    }

    # Type qualifiers

    method Files {} {
	set types files
	return
    }

    method Links {} {
	set types links
	return
    }

    method Directories {} {
	set types dirs
	return
    }

    method Everything {} {
	set types {}
	return
    }

    # State interogation

    method QueryState {} {
	return [list \
		    from      $src \
		    into      $base \
		    as        $alias \
		    op        $op \
		    excluded  $excl \
		    recursive $recursive \
		    type      $types \
		    strict    $strict \
		   ]
    }
    method QueryExcluded {} {
	return $excl
    }
    method QueryFrom {} {
	return $src
    }
    method QueryInto {} {
	return $base
    }
    method QueryAs {} {
	return $alias
    }
    method QueryOperation {} {
	return $op
    }
    method QueryRecursive {} {
	return $recursive
    }
    method QueryType {} {
	return $types
    }
    method QueryStrict {} {
	return $strict
    }

    # ### ### ### ######### ######### #########
    ## DSL State

    component stack       ; # State stack     - ( )
    variable  base     "" ; # Destination dir - into, in, cd, up
    variable  alias    "" ; # Detail          - as
    variable  op       "" ; # Operation       - move, copy, remove, expand, invoke
    variable  opcmd    "" ; # Command prefix for invoke.
    variable  recursive 0 ; # Op. qualifier: recursive expansion?
    variable  src      "" ; # Source dir      - from
    variable  excl     "" ; # Excluded files  - but not|exclude, except for
    # incl                ; # Included files  - the (immediate use)
    variable types     {} ; # Limit glob/find to specific types (f, l, d).
    variable strict    0  ; # Strictness of into/Expand

    variable lastexpansion "" ; # Area for last expansion result, for 'Save' to take from.

    # ### ### ### ######### ######### #########
    ## Internal -- Path manipulation helpers.

    proc ForceRelative {path} {
	set pathtype [file pathtype $path]
	switch -exact -- $pathtype {
	    relative {
		return $path
	    }
	    absolute {
		# Chop off the first element in the path, which is the
		# root, either '/' or 'x:/'. If this was the only
		# element assume an empty path.

		set path [lrange [file split $path] 1 end]
		if {![llength $path]} {return {}}
		return [eval [linsert $path 0 file join]]
	    }
	    volumerelative {
		return -code error {Unable to handle volumerelative path, yet}
	    }
	}

	return -code error \
	    "file pathtype returned unknown type \"$pathtype\""
    }

    proc ForceAbsolute {path} {
	return [file join [pwd] $path]
    }

    # ### ### ### ######### ######### #########
    ## Internal - Operation execution helpers

    proc Invoke {files} {
	upvar 1 base base src src opcmd opcmd
	uplevel #0 [linsert $opcmd end $src $base $files]
	return
    }

    proc Move {files} {
	upvar 1 base base src src

	foreach {s d} $files {
	    set s [file join $src  $s]
	    set d [file join $base $d]

	    file mkdir [file dirname $d]
	    file rename -force $s $d
	}
	return
    }

    proc Copy {files} {
	upvar 1 base base src src

	foreach {s d} $files {
	    set s [file join $src  $s]
	    set d [file join $base $d]

	    file mkdir [file dirname $d]
	    if {
		[file isdirectory $s] &&
		[file exists      $d] &&
		[file isdirectory $d]
	    } {
		# Special case: source and destination are
		# directories, and the latter exists. This puts the
		# source under the destination, and may even prevent
		# copying at all. The semantics of the operation is
		# that the source is the destination. We avoid the
		# trouble by copying the contents of the source,
		# instead of the directory itself.
		foreach path [glob -directory $s *] {
		    file copy -force $path $d
		}
	    } else {
		file copy -force $s $d
	    }
	}
	return
    }

    proc Remove {files} {
	upvar 1 base base

	foreach f $files {
	    file delete -force [file join $base $f]
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal -- Resolution helper commands

    typevariable tmap -array {
	files {f TFile}
	links {l TLink}
	dirs  {d TDir}
	{}    {{} {}}
    }

    proc Expand {dir pattern} {
	upvar 1 recursive recursive strict strict types types tmap tmap
	# FUTURE: struct::list filter ...

	set files {}
	if {$recursive} {
	    # Recursion through the entire directory hierarchy, save
	    # all matching paths.

	    set filter [lindex $tmap($types) 1]
	    if {$filter ne ""} {
		set filter [myproc $filter]
	    }

	    foreach f [fileutil::find $dir $filter] {
		if {![string match $pattern [file tail $f]]} continue
		lappend files [fileutil::stripPath $dir $f]
	    }
	} else {
	    # No recursion, just scan the whole directory for matching paths.
	    # check for specific types integrated.

	    set filter [lindex $tmap($types) 0]
	    if {$filter ne ""} {
		foreach f [glob -nocomplain -directory $dir -types $filter -- $pattern] {
		    lappend files [fileutil::stripPath $dir $f]
		}
	    } else {
		foreach f [glob -nocomplain -directory $dir -- $pattern] {
		    lappend files [fileutil::stripPath $dir $f]
		}
	    }
	}

	if {[llength $files]} {return $files}
	if {!$strict}         {return {}}

	return -code error \
	    "No files matching pattern \"$pattern\" in directory \"$dir\""
    }

    proc TFile {f} {file isfile $f}
    proc TDir  {f} {file isdirectory $f}
    proc TLink {f} {expr {[file type $f] eq "link"}}

    proc Exclude {files} {
	upvar 1 excl excl

	# FUTURE: struct::list filter ...
	set res {}
	foreach f $files {
	    if {[IsExcluded $f $excl]} continue
	    lappend res $f
	}
	return $res
    }

    proc IsExcluded {f patterns} {
	foreach p $patterns {
	    if {[string match $p $f]} {return 1}
	}
	return 0
    }

    proc Resolve {files} {
	upvar 1 alias alias
	set res {}
	foreach f $files {

	    # Remember alias for processing and auto-invalidate to
	    # prevent contamination of the next file.

	    set thealias $alias
	    set alias    ""

	    if {$thealias eq ""} {
		set d $f
	    } else {
		set d [file dirname $f]
		if {$d eq "."} {
		    set d $thealias
		} else {
		    set d [file join $d $thealias]
		}
	    }

	    lappend res $f $d
	}
	return $res
    }

    proc Remember {files} {
	upvar 1 lastexpansion lastexpansion
	set lastexpansion $files
	return $files
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide fileutil::multi::op 0.5.3
