#
# Extended object interface to entries in LDAP directories or LDIF files.
#
# (c) 2006-2018 Pierre David (pdagog@gmail.com)
#
# History:
#   2006/08/08 : pda : design
#

package require Tcl 8.5
package require snit		;# tcllib
package require uri 1.1.5	;# tcllib
package require base64		;# tcllib
package require ldap 1.9.2	;# tcllib, low level code for LDAP directories

package provide ldapx 1.2

##############################################################################
# LDAPENTRY object type
##############################################################################

snit::type ::ldapx::entry {
    #########################################################################
    # Variables
    #########################################################################

    #
    # Format of an individual entry
    # May be "standard" (standard LDAP entry, read from an LDAP directory
    # or from a LDIF channel) or "change" (LDIF change, or result of the
    # comparison of two standard entries).
    # Special : "uninitialized" means that this entry has not been used,
    # and the first use will initialize it.
    #

    variable format "uninitialized"

    #
    # DN
    #

    variable dn ""

    #
    # Standard entry
    #
    # Syntax:
    #   - array indexed by attribute names (lower case)
    #   - each value is the list of attributes
    #
    # The current state may be backed up in an internal state.
    # (see backup and restore methods)
    #

    variable attrvals -array {}

    variable backup 0
    variable bckav  -array {}
    variable bckdn  ""

    #
    # Change entry
    #
    # Syntax:
    #	{{<op> <parameters>} ... }
    #	    if <op> = mod
    #		{mod {{<modop> <attr> [ {<val1> ... <valn>} ]} ...} }
    #		where <modop> = modrepl, modadd, moddel
    #	    if <op> = add
    #		{add {<attr> {<val1> ... <valn>} ...}}
    #	    if <op> = del
    #		{del}
    #	    if <op> = modrdn
    #		{modrdn <newrdn> <deleteoldrdn> [ <newsuperior> ]}
    #

    variable change ""

    #########################################################################
    # Generic methods (for both standard and change entries)
    #########################################################################

    # Resets the entry to an empty state

    method reset {} {

	set format "uninitialized"
	set dn ""
	array unset attrvals
	set backup 0
	array unset bckav
	set bckdn  ""
	set change ""
    }

    # Returns current format

    method format {} {

	return $format
    }

    # Checks if entry is compatible with a certain format
    # errors out if not

    method compatible {ref} {

	if {$format eq "uninitialized"} then {
	    set format $ref
	} elseif {$format ne $ref} then {
	    return -code error \
		"Invalid operation on format $format (should be $ref)"
	}
    }

    # Get or set the current dn

    method dn {{newdn {-}}} {

	if {$newdn ne "-"} then {
	    set dn $newdn
	}
	return $dn
    }

    # Get the "superior" (LDAP slang word) part of current dn

    method superior {} {

	set pos [string first "," $dn]
	if {$pos == -1} then {
	    set r ""
	} else {
	    set r [string range $dn [expr {$pos+1}] end]
	}
	return $r
    }

    # Get the "rdn" part of current dn

    method rdn {} {

	set pos [string first "," $dn]
	if {$pos == -1} then {
	    set r ""
	} else {
	    set r [string range $dn 0 [expr {$pos-1}]]
	}
	return $r
    }

    # Get a printable form of the contents

    method print {} {

	set r "dn: $dn"
	switch -- $format {
	    uninitialized {
		# nothing
	    }
	    standard {
		foreach a [lsort [array names attrvals]] {
		    append r "\n$a: $attrvals($a)"
		}
	    }
	    change {
		if {[llength $change]} then {
		    append r "\n$change"
		}
	    }
	    default {
		append r " (inconsistent value)"
	    }
	}
	return $r
    }

    # Prints the whole state of an entry

    method debug {} {

	set r "dn = <$dn>\nformat = $format"
	switch -- $format {
	    uninitialized {
		# nothing
	    }
	    standard {
		foreach a [lsort [array names attrvals]] {
		    append r "\n\t$a: $attrvals($a)"
		}
		if {$backup} then {
		    append r "\nbackup dn = $bckdn"
		    foreach a [lsort [array names bckav]] {
			append r "\n\t$a: $bckav($a)"
		    }
		} else {
		    append r "\nno backup"
		}
	    }
	    change {
		if {[llength $change]} then {
		    append r "\n$change"
		} else {
		    append r "\nno change"
		}
	    }
	    default {
		append r " (inconsistent value)"
	    }
	}
	return $r
    }


    #########################################################################
    # Methods for standard entries
    #########################################################################

    # Tells if the current entry is empty

    method isempty {} {

	$self compatible "standard"

	return [expr {[array size attrvals] == 0}]
    }

    # Get all values for an attribute

    method get {attr} {

	$self compatible "standard"

	set a [string tolower $attr]
	if {[info exists attrvals($a)]} then {
	    set r $attrvals($a)
	} else {
	    set r {}
	}
	return $r
    }

    # Get only the first value for an attribute

    method get1 {attr} {

	return [lindex [$self get $attr] 0]
    }


    # Set all values for an attribute

    method set {attr vals} {

	$self compatible "standard"

	set a [string tolower $attr]
	if {[llength $vals]} then {
	    set attrvals($a) $vals
	} else {
	    unset -nocomplain attrvals($a)
	}
	return $vals
    }

    # Set only one value for an attribute

    method set1 {attr val} {

	if {$val eq ""} then {
	    set l {}
	} else {
	    set l [list $val]
	}

	return [$self set $attr $l]
    }

    # Add some values to an attribute

    method add {attr vals} {

	$self compatible "standard"

	set a [string tolower $attr]
	foreach v $vals {
	    lappend attrvals($a) $v
	}
	return $attrvals($a)
    }

    # Add only one value to an attribute

    method add1 {attr val} {

	return [$self add $attr [list $val]]
    }

    # Delete all values (or some values only) for an attribute

    method del {attr {vals {}}} {

	$self compatible "standard"

	set a [string tolower $attr]
	if {[llength $vals]} then {
	    set l [$self get $attr]
	    foreach v $vals {
		while {[set pos [lsearch -exact $l $v]] != -1} {
		    set l [lreplace $l $pos $pos]
		}
	    }
	} else {
	    set l {}
	}

	if {[llength $l]} then {
	    $self set $attr $l
	} else {
	    unset -nocomplain attrvals($a)
	}
	return
    }

    # Delete only one value from an attribute

    method del1 {attr val} {

	$self del $attr [list $val]
    }

    # Get all attribute names

    method getattr {} {

	$self compatible "standard"

	return [array names attrvals]
    }

    # Get all attribute names and values

    method getall {} {

	$self compatible "standard"

	return [array get attrvals]
    }

    # Reset all attribute names and values at once

    method setall {lst} {

	$self compatible "standard"

	array unset attrvals
	foreach {attr vals} $lst {
	    set a [string tolower $attr]
	    set attrvals($a) $vals
	}
    }

    # Back up current entry into a new one or into the internal backup state

    method backup {{other {}}} {

	$self compatible "standard"

	if {$other eq ""} then {
	    #
	    # Back-up entry in $self->$oldav and $self->$dn
	    #
	    set backup 1
	    set bckdn $dn

	    array unset bckav
	    array set bckav [array get attrvals]
	} else {
	    #
	    # Back-up entry in $other
	    #
	    $other compatible "standard"
	    $other dn $dn
	    $other setall [array get attrvals]
	}
    }

    # Restore current entry from an old one or from the internal backup state

    method restore {{other {}}} {

	$self compatible "standard"

	if {$backup} then {
	    if {$other eq ""} then {
		#
		# Restore in current context
		#
		set dn $bckdn
		array unset attrvals
		array set attrvals [array get bckav]
	    } else {
		#
		# Restore in another object
		#
		$other compatible "standard"
		$other dn $bckdn
		$other setall [array get bckav]
	    }
	} else {
	    return -code error \
		"Cannot restore a non backuped object"
	}
    }

    # Swap current and backup data, if they reside in the same entry

    method swap {} {

	$self compatible "standard"

	if {$backup} then {
	    #
	    # Swap current and backup contexts
	    #
	    set swdn $dn
	    set dn $bckdn
	    set bckdn $swdn

	    set swav [array get attrvals]
	    array unset attrvals
	    array set attrvals [array get bckav]
	    array unset bckav
	    array set bckav $swav
	} else {
	    return -code error \
		"Cannot swap a non backuped object"
	}
    }

    # Apply some modifications (given by a change entry) to current entry

    method apply {chg} {

	$self compatible "standard"
	$chg  compatible "change"

	#
	# Apply $chg modifications to $self
	#

	foreach mod [$chg change] {
	    set op [lindex $mod 0]
	    switch -- $op {
		add {
		    if {! [$self isempty]} then {
			return -code error \
			    "Cannot add an entry to a non-empty entry"
		    }
		    $self setall [lindex $mod 1]
		    if {[string equal [$self dn] ""]} then {
			$self dn [$chg dn]
		    }
		}
		mod {
		    foreach submod [lindex $mod 1] {
			set subop [lindex $submod 0]
			set attr [lindex $submod 1]
			set vals [lindex $submod 2]
			switch -- $subop {
			    modadd {
				$self add $attr $vals
			    }
			    moddel {
				$self del $attr $vals
			    }
			    modrepl {
				$self del $attr
				$self add $attr $vals
			    }
			    default {
				return -code error \
				    "Invalid submod operation '$subop'"
			    }
			}
		    }
		}
		del {
		    array unset attrvals
		}
		modrdn {
		    set newrdn [lindex $mod 1]
		    set delold [lindex $mod 2]
		    set newsup [lindex $mod 3]

		    if {! [regexp {^([^=]+)=([^,]+)$} $newrdn m nattr nval]} then {
			return -code "Invalid new RDN '$newrdn'"
		    }

		    set olddn  [$self dn]
		    if {! [regexp {^([^=]+)=([^,]+),(.*)} $olddn m oattr oval osup]} then {
			return -code "Invalid old DN '$olddn'"
		    }

		    if {$newsup eq ""} then {
			set dn "$newrdn,$osup"
		    } else {
			set dn "$newrdn,$newsup"
		    }
		    $self dn $dn

		    if {$delold} then {
			$self del1 $oattr $oval
		    }

		    # XXX should we ignore case ?
		    if {[lsearch -exact [$self get $nattr] $nval] == -1} then {
			$self add1 $nattr $nval
		    }
		}
		default {
		    return -code error \
			"Invalid change operation '$op'"
		}
	    }
	}
    }

    #########################################################################
    # Methods for change entries
    #########################################################################

    # Get or set all modifications

    method change {{newchg {-}}} {

	$self compatible "change"

	if {$newchg ne "-"} then {
	    set change $newchg
	}
	return $change
    }

    # Compute the difference between two entries (or between an entry
    # and the backed-up internal state) into the current change entry
    # e1 : new, e2 : old
    # if e2 is not given, it defaults to backup in e1

    method diff {new {old {}}} {

	$self compatible "change"

	#
	# Select where backup is. If internal, creates a temporary
	# standard entry.
	#

	if {$old eq ""} then {
	    set destroy_old 1
	    set old [::ldapx::entry create %AUTO%]
	    $new restore $old
	} else {
	    set destroy_old 0
	}

	#
	# Computes differences between values in the two entries
	#

	if {[$old dn] ne ""} then {
	    $self dn [$old dn]
	} elseif {[$new dn] ne ""} then {
	    $self dn [$new dn]
	} else {
	    $self dn ""
	}

	switch -- "[$new isempty][$old isempty]" {
	    00 {
		# They may differ
		set change [DiffEntries $new $old]
	    }
	    01 {
		# new has been added
		set change [list [list "add" [$new getall]]]
	    }
	    10 {
		# new has been deleted
		set change [list [list "del"]]
	    }
	    11 {
		# they are both empty: no change
		set change {}
	    }
	}

	#
	# Remove temporary standard entry (backup was internal)
	#

	if {$destroy_old} then {
	    $old destroy
	}

	return $change
    }

    # local procedure to compute differences between two non empty entries

    proc DiffEntries {new old} {
	array set tnew [$new getall]
	array set told [$old getall]

	set lmod {}

	#
	# First step : is there a DN change?
	#

	set moddn [DiffDn [$new dn] [$old dn] tnew told]

	#
	# Second step : pick up changes in attributes and/or values
	#

	foreach a [array names tnew] {
	    if {[info exists told($a)]} then {
		#
		# They are new and old values for this attribute.
		# We cannot use individual delete or add (rfc 4512,
		# paragraph 2.5.1) for attributes which do not have an
		# equality operator, so we use "replace" everywhere.
		#

		set lnew [lsort $tnew($a)]
		set lold [lsort $told($a)]
		if {$lold ne $lnew} then {
		    lappend lmod [list "modrepl" $a $tnew($a)]
		}

		unset tnew($a)
		unset told($a)
	    } else {
		lappend lmod [list "modadd" $a $tnew($a)]
		unset tnew($a)
	    }
	}

	foreach a [array names told] {
	    lappend lmod [list "moddel" $a]
	}

	set lchg {}

	if {[llength $lmod]} then {
	    lappend lchg [list "mod" $lmod]
	}

	#
	# Third step : insert modDN changes
	#

	if {[llength $moddn]} then {
	    set newrdn       [lindex $moddn 0]
	    set deleteoldrdn [lindex $moddn 1]
	    set newsuperior  [lindex $moddn 2]

	    set lmod [list "modrdn" $newrdn $deleteoldrdn]
	    if {! [string equal $newsuperior ""]} then {
		lappend lmod $newsuperior
	    }
	    lappend lchg $lmod
	}

	return $lchg
    }

    proc DiffDn {newdn olddn _tnew _told} {
	upvar $_tnew tnew
	upvar $_told told

	#
	# If DNs are the same, exit
	#

	if {[string equal -nocase $newdn $olddn]} then {
	    return {}
	}

	#
	# Split components of both DNs : attribute, value, superior
	#

	if {! [regexp {^([^=]+)=([^,]+),(.*)} $olddn m oattr oval osup]} then {
	    return -code "Invalid old DN '$olddn'"
	}
	set oattr [string tolower $oattr]
	set ordn "$oattr=$oval"

	if {! [regexp {^([^=]+)=([^,]+),(.*)} $newdn m nattr nval nsup]} then {
	    return -code "Invalid new DN '$newdn'"
	}
	set nattr [string tolower $nattr]
	set nrdn "$nattr=$nval"

	#
	# Checks if superior has changed
	#

	if {! [string equal -nocase $osup $nsup]} then {
	    set newsuperior $nsup
	} else {
	    set newsuperior ""
	}

	#
	# Checks if rdn has changed
	#

	if {! [string equal -nocase $ordn $nrdn]} then {
	    #
	    # Checks if old rdn must be deleted
	    #

	    set deleteoldrdn 1
	    if {[info exists tnew($oattr)]} then {
		set pos [lsearch -exact [string tolower $tnew($oattr)] \
					[string tolower $oval]]
		if {$pos != -1} then {
		    set deleteoldrdn 0
		}
	    }

	    #
	    # Remove old and new rdn such as DiffEntries doesn't
	    # detect any modification.
	    #

	    foreach t {tnew told} {
		foreach {a v} [list $oattr $oval $nattr $nval] {
		    if {[info exists ${t}($a)]} then {
			set l [set ${t}($a)]
			set pos [lsearch -exact [string tolower $l] \
						[string tolower $v] ]
			if {$pos != -1} then {
			    set l [lreplace $l $pos $pos]
			    if {[llength $l]} then {
				set ${t}($a) $l
			    } else {
				unset -nocomplain ${t}($a)
			    }
			}
		    }
		}
	    }
	} else {
	    set deleteoldrdn 0
	}

	return [list $nrdn $deleteoldrdn $newsuperior]
    }


    #########################################################################
    # End of ldapentry
    #########################################################################
}

##############################################################################
# UTF8 translator, component used to manage the -utf8 option
##############################################################################

snit::type ::ldapx::utf8trans {

    #########################################################################
    # Option
    #########################################################################

    option -utf8	 -default {{.*} {}}

    #########################################################################
    # Methods
    #########################################################################

    method must {attr} {
	set utf8yes [lindex $options(-utf8) 0]
	set utf8no  [lindex $options(-utf8) 1]
	set r 0
	if {[regexp -expanded -nocase "^$utf8yes$" $attr]} then {
	    set r 1
	    if {[regexp -expanded -nocase "^$utf8no$" $attr]} then {
		set r 0
	    }
	}
	return $r
    }

    method encode {attr val} {
	if {[$self must $attr]} then {
	    set val [encoding convertto utf-8 $val]
	}
	return $val
    }

    method decode {attr val} {
	if {[$self must $attr]} then {
	    set val [encoding convertfrom utf-8 $val]
	}
	return $val
    }

    method encodepairs {avpairs} {
	set r {}
	foreach {attr vals} $avpairs {
	    if {[llength $vals]} then {
		lappend r $attr [$self encode $attr $vals]
	    } else {
		lappend r $attr
	    }
	}
	return $r
    }

    method decodepairs {avpairs} {
	set r {}
	foreach {attr vals} $avpairs {
	    set vals [$self decode $attr $vals]
	    lappend r $attr $vals
	}
	return $r
    }
}

##############################################################################
# LDAP object type
##############################################################################

snit::type ::ldapx::ldap {
    #########################################################################
    # Options
    #
    # note : options are lowercase
    #########################################################################

    option -scope        -default "sub"
    option -derefaliases -default "never"
    option -sizelimit	 -default 0
    option -timelimit	 -default 0
    option -attrsonly	 -default 0

    option -tlsoptions  -default {}

    component translator
    delegate option -utf8 to translator

    #
    # Channel descriptor
    #

    variable channel ""
    variable bind 0

    #
    # Last error
    #

    variable lastError ""

    #
    # Defaults connection modes
    #

    variable connect_defaults -array {
				    ldap {389 ::ldap::connect}
				    ldaps {636 ::ldap::secure_connect}
				}


    #########################################################################
    # Constructor
    #########################################################################

    constructor {args} {
	install translator using ::ldapx::utf8trans create %AUTO%
	$self configurelist $args
    }

    destructor {
	catch {$translator destroy}
    }

    #########################################################################
    # Methods
    #########################################################################

    # Get or set the last error message

    method error {{le {-}}} {

	if {! [string equal $le "-"]} then {
	    set lastError $le
	}
	return $lastError
    }

    # Connect to the LDAP directory, and binds to it if needed

    method connect {url {binddn {}} {bindpw {}} {starttls no}} {

	array set comp [::uri::split $url "ldap"]

	if {! [::info exists comp(host)]} then {
	    $self error "Invalid host in URL '$url'"
	    return 0
	}

	# use ::ldap with integrated TLS mode
	::ldap::tlsoptions reset
	::ldap::tlsoptions {*}$options(-tlsoptions)

	set scheme $comp(scheme)
	if {! [::info exists connect_defaults($scheme)]} then {
	    $self error "Unrecognized URL '$url'"
	    return 0
	}

	set defport [lindex $connect_defaults($scheme) 0]
	set fct     [lindex $connect_defaults($scheme) 1]

	if {[string equal $comp(port) ""]} then {
	    set comp(port) $defport
	}

	if {[Check $selfns {set channel [$fct $comp(host) $comp(port)]}]} then {
	    return 0
	}

	if {$starttls && [string equal $scheme "ldap"]} then {
	    if {[Check $selfns {::ldap::starttls $channel}]} then {
		return 0
	    }
	}

	if {$binddn eq ""} then {
	    set bind 0
	} else {
	    set bind 1
	    if {[Check $selfns {::ldap::bind $channel $binddn $bindpw}]} then {
		return 0
	    }
	}
	return 1
    }

    # Disconnect from the LDAP directory

    method disconnect {} {

	Connected $selfns

	if {$bind} {
	    if {[Check $selfns {::ldap::unbind $channel}]} then {
		return 0
	    }
	}
	if {[Check $selfns {::ldap::disconnect $channel}]} then {
	    return 0
	}
	set channel ""
	return 1
    }

    # New control structure : traverse the DIT and execute the body
    # for each found entry.

    method traverse {base filter attrs entry body} {

	Connected $selfns

	global errorInfo errorCode

	set lastError ""

	#
	# Initiate search
	#

	set opt [list                                             \
			-scope        $options(-scope)            \
			-derefaliases $options(-derefaliases)     \
			-sizelimit    $options(-sizelimit)        \
			-timelimit    $options(-timelimit)        \
			-attrsonly    $options(-attrsonly)        \
			]

	::ldap::searchInit $channel $base $filter $attrs $opt

	#
	# Execute the specific body for each result found
	#

	while {1} {
	    #
	    # The first call to searchNext may fail when searchInit
	    # is given some invalid parameters.
	    # We must terminate the current search in order to allow
	    # future searches.
	    #

	    set err [catch {::ldap::searchNext $channel} r]

	    if {$err} then {
		set ei $errorInfo
		set ec $errorCode
		::ldap::searchEnd $channel
		return -code error -errorinfo $ei -errorcode $ec $r
	    }

	    #
	    # End of result messages
	    #

	    if {[llength $r] == 0} then {
		break
	    }

	    #
	    # Set DN and attributes-values (converted from utf8 if needed)
	    # for the entry
	    #

	    $entry reset

	    $entry dn [lindex $r 0]
	    $entry setall [$translator decodepairs [lindex $r 1]]

	    #
	    # Execute body with the entry
	    #
	    # http://wiki.tcl.tk/685
	    #

	    set code [catch {uplevel 1 $body} msg]
	    switch -- $code {
		0 {
		    # ok
		}
		1 {
		    # error
		    set ei $errorInfo
		    set ec $errorCode
		    ::ldap::searchEnd $channel
		    return -code error -errorinfo $ei -errorcode $ec $msg
		}
		2 {
		    # return
		    ::ldap::searchEnd $channel
		    return -code return $msg
		}
		3 {
		    # break
		    ::ldap::searchEnd $channel
		    return {}
		}
		4 {
		    # continue
		}
		default {
		    # user defined
		    ::ldap::searchEnd $channel
		    return -code $code $msg
		}
	    }
	}

	#
	# Terminate search
	#

	::ldap::searchEnd $channel
    }

    # Returns a list of newly created objects which match

    method search {base filter attrs} {

	Connected $selfns

	set e [::ldapx::entry create %AUTO%]
	set r {}
	$self traverse $base $filter $attrs $e {
	    set new [::ldapx::entry create %AUTO%]
	    $e backup $new
	    lappend r $new
	}
	$e destroy
	return $r
    }

    # Read one or more entries, and returns the number of entries found.
    # Useful to easily read one or more entries.

    method read {base filter args} {

	set n 0
	set max [llength $args]
	set e [::ldapx::entry create %AUTO%]
	$self traverse $base $filter {} $e {
	    if {$n < $max} then {
		$e backup [lindex $args $n]
	    }
	    incr n
	}
	return $n
    }

    # Commit a list of changes (or standard, backuped entries)

    method commit {args} {

	Connected $selfns

	foreach entry $args {
	    switch -- [$entry format] {
		uninitialized {
		    return -code error \
			"Uninitialized entry"
		}
		standard {
		    set echg [::ldapx::entry create %AUTO%]
		    set lchg [$echg diff $entry]
		    set dn   [$echg dn]
		    $echg destroy
		}
		change {
		    set dn   [$entry dn]
		    set lchg [$entry change]
		}
	    }

	    foreach chg $lchg {
		set op   [lindex $chg 0]

		switch -- $op {
		    {} {
			# nothing to do
		    }
		    add {
			set av [$translator encodepairs [lindex $chg 1]]
			if {[Check $selfns {::ldap::addMulti $channel $dn $av}]} then {
			    return 0
			}
		    }
		    del {
			if {[Check $selfns {::ldap::delete $channel $dn}]} then {
			    return 0
			}
		    }
		    mod {
			set lrep {}
			set ldel {}
			set ladd {}

			foreach submod [lindex $chg 1] {
			    set subop [lindex $submod 0]
			    set attr [lindex $submod 1]
			    set vals [lindex $submod 2]

			    set vals [$translator encode $attr $vals]
			    switch -- $subop {
				modadd {
				    lappend ladd $attr $vals
				}
				moddel {
				    lappend ldel $attr $vals
				}
				modrepl {
				    lappend lrep $attr $vals
				}
			    }
			}

			if {[Check $selfns {::ldap::modifyMulti $channel $dn \
						    $lrep $ldel $ladd}]} then {
			    return 0
			}
		    }
		    modrdn {
			set newrdn [lindex $chg 1]
			set delOld [lindex $chg 2]
			set newSup [lindex $chg 3]
			if {[string equal $newSup ""]} then {
			    if {[Check $selfns {::ldap::modifyDN $channel $dn \
						    $newrdn $delOld}]} then {
				return 0
			    }
			} else {
			    if {[Check $selfns {::ldap::modifyDN $channel $dn \
						    $newrdn $delOld $newSup}]} then {
				return 0
			    }
			}
		    }
		}
	    }
	}

	return 1
    }

    #########################################################################
    # Local procedures
    #########################################################################

    proc Connected {selfns} {
	if {$channel eq ""} then {
	    return -code error \
		"Object not connected"
	}
    }

    proc Check {selfns script} {
	return [catch {uplevel 1 $script} lastError]
    }

    #########################################################################
    # End of LDAP object type
    #########################################################################
}

##############################################################################
# LDIF object type
##############################################################################

snit::type ::ldapx::ldif {

    #########################################################################
    # Options
    #########################################################################

    #
    # Fields to ignore when reading change file
    #

    option -ignore {}

    component translator
    delegate option -utf8 to translator


    #########################################################################
    # Variables
    #########################################################################

    #
    # Version of LDIF file (0 means : uninitialized)
    #

    variable version 0

    #
    # Channel descriptor
    #

    variable channel ""

    #
    # Line number
    #

    variable lineno 0

    #
    # Last error message
    #

    variable lastError ""

    #
    # Number of entries read or written
    #

    variable nentries 0

    #
    # Type of LDIF file
    #

    variable format "uninitialized"

    #########################################################################
    # Constructor
    #########################################################################

    constructor {args} {
	install translator using ::ldapx::utf8trans create %AUTO%
	$self configurelist $args
    }

    destructor {
	catch {$translator destroy}
    }

    #########################################################################
    # Methods
    #########################################################################

    # Initialize a channel

    method channel {newchan} {

	set channel   $newchan
	set version   0
	set nentries  0
	set format    "uninitialized"
	set lineno    0
	return
    }

    # Get or set the last error message

    method error {{le {-}}} {

	if {$le ne "-"} then {
	    set lastError $le
	}
	return $lastError
    }

    # An LDIF file cannot include both changes and standard entries
    # (see RFC 2849, page 2). Check this.

    method compatible {ref} {

	if {$format eq "uninitialized"} then {
	    set format $ref
	} elseif {$format ne $ref} then {
	    return -code error \
		"Invalid entry ($ref) type for LDIF $format file"
	}
    }

    # Reads an LDIF entry (standard or change) from the channel
    # returns 1 if ok, 0 if error or EOF

    # XXX this method is just coded for tests at this time

    method debugread {entry} {

	$entry compatible "standard"
	$entry dn "uid=joe,ou=org,o=com"
	$entry setall {uid {joe} sn {User} givenName {Joe} cn {{Joe User}}
	    telephoneNumber {+31415926535 +27182818285} objectClass {person}
	}
	return 1
    }

    # Read an LDIF entry (standard or change) from the channel
    # returns 1 if ok, 0 if error or EOF

    method read {entry} {
	if {$channel eq ""} then {
	    return -code error \
			"Channel not initialized"
	}

	set r [Lexical $selfns]
	if {[lindex $r 0] ne "err"} then {
	    set r [Syntaxic $selfns [lindex $r 1]]
	}

	if {[lindex $r 0] eq "err"} then {
	    set lastError [lindex $r 1]
	    return 0
	}

	switch -- [lindex $r 0] {
	    uninitialized {
		$entry reset
		set lastError ""
		set r 0
	    }
	    standard {
		if {[catch {$self compatible "change"}]} then {
		    set lastError "Standard entry not allowed in LDIF change file"
		    set r 0
		} else {
		    $entry reset
		    $entry dn     [lindex $r 1]
		    $entry setall [lindex $r 2]
		    set r 1
		}
	    }
	    change {
		if {[catch {$self compatible "change"}]} then {
		    set lastError "Change entry not allowed in LDIF standard file"
		    set r 0
		} else {
		    $entry reset
		    $entry dn     [lindex $r 1]
		    $entry change [list [lindex $r 2]]
		    set r 1
		}
	    }
	    default {
		return -code error \
			"Internal error (invalid returned entry format)"
	    }
	}

	return $r
    }

    # Write an LDIF entry to the channel

    method write {entry} {

	if {$channel eq ""} then {
	    return -code error \
			"Channel not initialized"
	}

	switch -- [$entry format] {
	    uninitialized {
		# nothing
	    }
	    standard {
		if {[llength [$entry getall]]} then {
		    $self compatible "standard"

		    if {$nentries == 0} then {
			if {$version == 0} then {
			    set version 1
			}
			WriteLine $selfns "version" "$version"
			puts $channel ""
		    }

		    WriteLine $selfns "dn" [$entry dn]

		    foreach a [$entry getattr] {
			foreach v [$entry get $a] {
			    WriteLine $selfns $a $v
			}
		    }
		    puts $channel ""
		}
	    }
	    change {
		$self compatible "change"

		set lchg [$entry change]
		foreach chg $lchg {
		    if {$nentries == 0} then {
			if {$version == 0} then {
			    set version 1
			}
			WriteLine $selfns "version" "$version"
			puts $channel ""
		    }

		    WriteLine $selfns "dn" [$entry dn]

		    set op [lindex $chg 0]
		    switch -- $op {
			add {
			    WriteLine $selfns "changetype" "add"
			    foreach {attr vals} [lindex $chg 1] {
				foreach v $vals {
				    WriteLine $selfns $attr $v
				}
			    }
			}
			del {
			    WriteLine $selfns "changetype" "delete"
			}
			mod {
			    WriteLine $selfns "changetype" "modify"
			    foreach submod [lindex $chg 1] {
				set subop [lindex $submod 0]
				set attr [lindex $submod 1]
				set vals [lindex $submod 2]

				switch -- $subop {
				    modadd {
					WriteLine $selfns "add" $attr
				    }
				    moddel {
					WriteLine $selfns "delete" $attr
				    }
				    modrepl {
					WriteLine $selfns "replace" $attr
				    }
				}
				foreach v $vals {
				    WriteLine $selfns $attr $v
				}
				puts $channel "-"
			    }
			}
			modrdn {
			    WriteLine $selfns "changetype" "modrdn"
			    set newrdn [lindex $chg 1]
			    set delold [lindex $chg 2]
			    set newsup [lindex $chg 3]
			    WriteLine $selfns "newrdn" $newrdn
			    WriteLine $selfns "deleteOldRDN" $delold
			    if {$newsup ne ""} then {
				WriteLine $selfns "newSuperior" $newsup
			    }
			}
		    }
		    puts $channel ""
		    incr nentries
		}
	    }
	    default {
		return -code error \
			"Invalid entry format"
	    }
	}
	return 1
    }

    #########################################################################
    # Local procedures to read an entry
    #########################################################################

    #
    # Lexical analysis of an entry
    # Special case for "version:" entry.
    # Returns a list of lines {ok {{<attr1> <val1>} {<attr2> <val2>} ...}}
    # or a list {err <message>}
    #

    proc Lexical {selfns} {
	set result {}
	set prev ""

	while {[gets $channel line] > -1} {
	    incr lineno

	    if {$line eq ""} then {
		#
		# Empty line: we are either before the beginning
		# of the entry or at the empty line after the
		# entry.
		# We don't give up before getting something.
		#

		if {! [FlushLine $selfns "" result prev msg]} then {
		    return [list "err" $msg]
		}

		if {[llength $result]} then {
		    break
		}

	    } elseif {[regexp {^[ \t]} $line]} then {
		#
		# Continuation line. Remove the continuation character.
		#

		append prev [string range $line 1 end]

	    } elseif {[regexp {^-$} $line]} then {
		#
		# Separation between individual modifications
		#

		if {! [FlushLine $selfns "" result prev msg]} then {
		    return [list "err" $msg]
		}
		lappend result [list "-" {}]

	    } else {
		#
		# Should be a normal line (key: val)
		#

		if {! [FlushLine $selfns $line result prev msg]} then {
		    return [list "err" $msg]
		}

	    }
	}

	#
	# End of file, or end of entry. Flush buffered data from $prev
	# for EOF case.
	#

	if {! [FlushLine $selfns "" result prev msg]} then {
	    return [list "err" $msg]
	}

	return [list "ok" $result]
    }

    proc FlushLine {selfns line _result _prev _msg} {
	upvar $_result result  $_prev prev  $_msg msg

	if {$prev ne ""} then {
	    set r [DecodeLine $selfns $prev]
	    if {[llength $r] != 2} then {
		set msg "$lineno: invalid syntax"
		return 0
	    }

	    #
	    # Special case for "version: 1". This code should not
	    # be in lexical analysis, but this would be too disruptive
	    # in syntaxic analysis
	    #

	    if {[string equal -nocase [lindex $r 0] "version"]} then {
		if {$version != 0} then {
		    set msg "version attribute allowed only at the beginning of the LDIF file"
		    return 0
		}
		set val [lindex $r 1]
		if {[catch {set val [expr {$val+0}]}]} then {
		    set msg "invalid version value"
		    return 0
		}
		if {$val != 1} then {
		    set msg "unrecognized version '$val'"
		    return 0
		}
		set version 1
	    } else {
		lappend result $r
	    }
	}
	set prev $line

	return 1
    }

    proc DecodeLine {selfns str} {
	if {[regexp {^([^:]*)::[ \t]*(.*)} $str d key val]} then {
	    set key [string tolower $key]
	    set val [::base64::decode $val]
	    set val [$translator decode $key $val]
	    set r [list $key $val]
	} elseif {[regexp {^([^:]*):[ \t]*(.*)} $str d key val]} then {
	    set key [string tolower $key]
	    set val [$translator decode $key $val]
	    set r [list $key $val]
	} else {
	    # syntax error
	    set r {}
	}
	return $r
    }

    #
    # Array indexed by current state of the LDIF automaton
    # Each element is a list of actions, each with the format:
    #	pattern on on "attribute:value"
    #	next state
    #	script (to be evaled in Syntaxic local procedure)
    #

    variable ldifautomaton -array {
	begin {
	    {dn:*		dn		{set dn $val}}
	    {EOF:*		end		{set r [list "empty"]}}
	}
	dn {
	    {changetype:modify	mod		{set t "change" ; set r {mod}}}
	    {changetype:modrdn	modrdn		{set t "change" ; set newsup {}}}
	    {changetype:add	add		{set t "change"}}
	    {changetype:delete	del		{set t "change"}}
	    {*:*		standard	{set t "standard" ; lappend tab($key) $val}}
	}
	standard {
	    {EOF:*		end		{set r [array get tab]}}
	    {*:*		standard	{lappend tab($key) $val}}
	}
	mod {
	    {add:*		mod-add		{set attr [string tolower $val] ; set vals {}}}
	    {delete:*		mod-del		{set attr [string tolower $val] ; set vals {}}}
	    {replace:*		mod-repl	{set attr [string tolower $val] ; set vals {}}}
	    {EOF:*		end		{}}
	}
	mod-add {
	    {*:*		mod-add-attr	{lappend vals $val}}
	}
	mod-add-attr {
	    {-:*		mod		{lappend r [list "modadd" $attr $vals]}}
	    {*:*		mod-add-attr	{lappend vals $val}}
	}
	mod-del {
	    {-:*		mod		{lappend r [list "moddel" $attr $vals]}}
	    {*:*		mod-del		{lappend vals $val}}
	}
	mod-repl {
	    {-:*		mod		{lappend r [list "modrepl" $attr $vals]}}
	    {*:*		mod-repl	{lappend vals $val}}
	}
	modrdn {
	    {newrdn:*		modrdn-new	{set newrdn $val}}
	}
	modrdn-new {
	    {deleteoldrdn:0	modrdn-del	{set delold 0}}
	    {deleteoldrdn:1	modrdn-del	{set delold 1}}
	}
	modrdn-del {
	    {newsuperior:*	modrdn-end	{set newsup $val}}
	    {EOF:*		end		{set r [list modrdn $newrdn $delold] }}
	}
	modrdn-end {
	    {EOF:*		end		{set r [list modrdn $newrdn $delold $newsup]}}
	}
	add {
	    {EOF:*		end		{set r [list add [array get tab]]}}
	    {*:*		add		{lappend tab($key) $val}}
	}
	del {
	    {EOF:*		end		{set r [list del]}}
	}
    }

    proc Syntaxic {selfns lcouples} {
	set state "begin"
	set newsup {}
	set t "uninitialized"
	foreach c $lcouples {
	    set key [lindex $c 0]
	    if {[lsearch [string tolower $options(-ignore)] $key] == -1} then {
		set val [lindex $c 1]
		set a [Automaton $selfns $state $key $val]
		if {$a eq ""} then {
		    return [list "err" "Syntax error before line $lineno"]
		}
		set state [lindex $a 0]
		set script [lindex $a 1]
		eval $script
	    }
	}

	set a [Automaton $selfns $state "EOF" "EOF"]
	if {$a eq ""} then {
	    return [list "err" "Premature EOF"]
	}
	set script [lindex $a 1]
	eval $script

	set result [list $t]
	switch $t {
	    uninitialized {
		# nothing
	    }
	    standard {
		lappend result $dn $r
	    }
	    change {
		lappend result $dn $r
	    }
	}

	return $result
    }

    proc Automaton {selfns state key val} {
	set r {}
	if {[info exists ldifautomaton($state)]} then {
	    foreach a $ldifautomaton($state) {
		if {[string match [lindex $a 0] "$key:$val"]} then {
		    set r [lreplace $a 0 0]
		    break
		}
	    }
	}
	return $r
    }

    #########################################################################
    # Local procedures to write an entry
    #########################################################################

    proc WriteLine {selfns attr val} {

	if {[string is ascii $val] && [string is print $val]} then {
	    set sep ":"
	} else {
	    set sep "::"
	    set val [$translator encode $attr $val]
	    set val [::base64::encode $val]
	}

	set first 1
	foreach line [split $val "\n"] {
	    if {$first} then {
		puts $channel "$attr$sep $line"
		set first 0
	    } else {
		puts $channel " $line"
	    }
	}
    }
}
