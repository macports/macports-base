#----------------------------------------------*-TCL-*------------
#
#  units.tcl
#
#  The units package provides a conversion facility from a variety of
#  scientific and engineering shorthand notations into floating point
#  numbers.
#
#  Sean Woods
#  November 4, 2016
#  Test and Evaluation Solutions, LLC
#
#  Robert W. Techentin
#  November 1, 2000
#  Copyright (C) Mayo Foundation.  All Rights Reserved.
#
#-----------------------------------------------------------------
package provide units 2.2.1

package require Tcl 8.5

namespace eval ::units {

    namespace export new
    namespace export convert
    namespace export reduce

    variable UnitList
    variable PrefixTable
}


#-----------------------------------------------------------------
#
# ::units::new --
#
#  Add a new unit to the units table.  The new unit is defined
#  in terms of its baseUnits.  If baseUnits is "-primitive",
#  then it is assumed to be some magical new kind of quantity.
#  Otherwise, it must reduce to units already defined.
#
#-----------------------------------------------------------------
proc ::units::new {name baseUnits} {
    variable UnitList

    # check for duplicates
    if { [dict exists $UnitList $name] } {
	error "unit '$name' is already defined"
    }

    # check for valid characters
    if { [regexp {[^a-zA-Z_]} $name] } {
	error "non-alphabetic characters in unit name '$name'"
    }

    # Compute reduced units
    if { [catch {::units::reduce $baseUnits} reducedUnits] } {
	error "'$baseUnits' cannot be reduced to primitive units"
    }

    # add the unit, but don't return a value
    dict set UnitList $name $reducedUnits
    return
}

#-----------------------------------------------------------------
#
# ::units::convert --
#
#  Convert a value to the target units.
#
#  If units are specified for the value, then they must
#  be compatible with the target units.  (i.e., you can 
#  convert "newtons" to "kg-m/s^2", but not to "sieverts".
#
# Arguments:
#  value  A value can be a floating point number, either with or
#         without units.  
#  targetUnits  A units string which  may also include a scale factor.  
#
# Results:
#  The return value is a scaled floating point number.
#
#-----------------------------------------------------------------

proc ::units::convert {value targetUnits} {
    #  Reduce each of value and target
    #  to primitive units
    set reducedValue [::units::reduce $value]
    set reducedTarget [::units::reduce $targetUnits]
    
    set operation {}
    if {[llength $reducedValue]==4 && [lindex $reducedValue 1] in {+ -}} {
	if {[lindex $reducedValue 1] eq "+"} {
	    lappend operation ( [lindex $reducedValue 0] - [lindex $reducedValue 2] )
	} else {
	    lappend operation ( [lindex $reducedValue 0] + [lindex $reducedValue 2] )
	}
	set reducedValue [reduce [lindex $reducedValue 3]]
	lappend operation * [lindex $reducedValue 0] /
    } else {
	lappend operation [lindex $reducedValue 0] /
    }
    if {[llength $reducedTarget]==4 && [lindex $reducedTarget 1] in {+ -}} {
	set postop [lrange $reducedTarget 0 2]
	set reducedTarget  [reduce [lindex $reducedTarget 3]]
	lappend operation  [lindex $reducedTarget 0] * {*}$postop
    } else {
	lappend operation [lindex $reducedTarget 0]
    }
    #  If the value has units, it must be compatible with
    #  the target.  (If it is unitless, then compatibility
    #  is not required.)
    if { [llength $reducedValue] > 1} {
	if {[lrange $reducedValue 1 end]!=[lrange $reducedTarget 1 end]} {
	    error "'$value' and '$targetUnits' have incompatible units"
	}
    }
    #  Compute and return scaled and transformed value
    return [expr $operation]
}


#-----------------------------------------------------------------
#
# ::units::reduce --
#
#  Reduce a string of numbers, prefixes, units, exponents into a
#  single multiplicitive factor and sorted list of primitive units.
#  For example, the unit string for "newton", which is "m-kg/s^2"
#  would reduce to the list {1000.0 gram meter / second second}
#
#  Unit String Syntax
#
#  This procedure defines a valid unit string that may
#  be reduced to primitive units, so it is reasonable to
#  document valid unit string syntax here.
#
#  A unit string consists of an optional scale factor followed
#  by zero or more subunit strings.  The scale factor must be
#  a valid floating point number.  
#
#  Subunits are separated by unit separator characters, which are 
#  " ", "-", "*", and "/".  It is not necessary to separate
#  the leading scale factor from the rest of the subunits.
#
#  The forward slash seperator "/" indicates that following
#  subunits are in the denominator.  There can be at most
#  one "/" separator.
#
#  Subunits can be floating point scale factors, but they
#  must be surrounded by valid separators.
#
#  Subunits can be valid units or abbreviations from the
#  UnitsTable.  They may include a prefix from the PrefixTable.
#  They may include a plural suffix "s" or "es".  They may
#  also include a power string "^", followed by an integer,
#  after the unit name (or plural suffix, if there is one.)
#
#  Examples of valid unit strings:  "meter", "/s", "kg-m/s^2",
#  "30second" "30 second", "30 seconds" "200*meter/20.5*second"
#
# Arguments:
#  unitString  string of units characters
#
# Results:
#  The return value is a list, the first element of which 
#  is the multiplicitive factor, and the remaining elements are
#  sorted reduced primitive units, possibly including the "/"
#  operator, which separates the numerator from the denominator.
#-----------------------------------------------------------------
#

proc ::units::reduce unitString {
    #  Check number of arguments

    # check for primitive unit - may already be reduced
    #  This gets excercised by new units
    if { "$unitString" == "-primitive" } {
	return $unitString
    }
    if { [string range $unitString 0 1] == "+ " } {
	return $unitString
    }
    if { [string range $unitString 0 1] == "- " } {
	return $unitString
    }

    # trim leading and trailing white space
    set unitString [string trim $unitString]

    # Check cache of unitStrings
   if { [info exists ::units::cache($unitString)] } {
	return $::units::cache($unitString)
    }

    # Verify syntax of unit string
    #  It may contain, at most, one "/"
    if { [regexp {/.*/} $unitString] } {
	error "invalid unit string '$unitString':  only one '/' allowed"
    }
    #  It may contain only letters, digits, the powerstring ("^"),
    #  decimal points, and separators 
    if { [regexp {[^a-zA-Z0-9. \t*^/+-]} $unitString] } {
	error "invalid characters in unit string '$unitString'"
    }

    #  Check for leading scale factor
    #  If the leading characters are in floating point
    #  format, then extract and save them (including any
    #  minus signs) before handling subunit separators.
    #  This is based on a regexp from Roland B. Roberts which
    #  allows leading +/-, digits, decimals, and exponents.
    regexp {(^[-+]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?)?(.*)} \
	    $unitString matchvar scaleFactor subunits
    #  Ensure that scale factor is a nice floating point number
    if { "$scaleFactor" == "" } {
	set scaleFactor 1.0
    } else {
	# convert to floating point, forcing leading
	# zeros to NOT mean octal. (bug 758702)
	scan $scaleFactor "%f" scaleFactor
    }

    #  replace all separators with spaces.
    regsub -all {[\t\-\*]} $subunits " " subunits
    #  add spaces around "/" character.
    regsub {/} $subunits " / " subunits

    #  The unitString is now essentially a well structured list
    #  of subunits, which may be processed as a list, and it
    #  may be necessary to process it recursively, without
    #  performing the string syntax checks again.  But check
    #  for errors.
    if { [catch {ReduceList $scaleFactor $subunits} result errdat] } {
	#puts [dict get $errdat -errorinfo]
	error "$result in '$unitString'"
    }

    #  Store the reduced unit in a cache, so future lookups
    #  are much quicker.
    set ::units::cache($unitString) $result
}


# Utility Function - Reduce factor/numerator/denominator
proc ::units::_ReduceList_term {factor numerator denominator} {

    #  Sort both numerator and denominator
    set numerator [lsort $numerator]
    set denominator [lsort $denominator]

    #  Cancel any duplicate units.
    #  Foreach and for loops don't work well for this.
    #  (We keep changing list length).
    set i 0
    while {$i < [llength $numerator]} {
	set u [lindex $numerator $i]
	set index [lsearch $denominator $u]
	if { $index >= 0 } {
	    set numerator [lreplace $numerator $i $i]
	    set denominator [lreplace $denominator $index $index]
	} else {
	    incr i
	}
    }

    #  Now we've got numerator, denominator, and factors.
    #  Assemble the result into a single list.
    if { [llength $denominator] > 0 } {
	set result [eval ::list $factor $numerator "/" $denominator]
    } else {
	set result [eval ::list $factor $numerator]
    }

    #  Now return the result
    return $result
}
#-----------------------------------------------------------------
#
# ::units::ReduceList --
#
#  Reduce a list of subunits to primitive units and a single
#  scale factor.
#
# Arguments:
#  factor      A scale factor, which is multiplied and divided
#              by subunit prefix values and constants.
#  unitString  A unit string which is syntactically correct
#              and includes only space separators.  This
#              string can be treated as a Tcl list.
#
# Results:
#  A valid unit string list, consisting of a single floating
#  point factor, followed by sorted primitive units.  If the 
#  forward slash separator "/" is included, then each of the
#  numerator and denominator is sorted, and common units have
#  been cancelled.
#
#-----------------------------------------------------------------
#
proc ::units::ReduceList { factor unitString } {
  variable UnitList
  variable PrefixTable

  # process each subunit in turn, starting in the numerator
  #
  #  Note that we're going to use a boolean flag to switch
  #  between numerator and denominator if we encounter a "/".
  #  This same style is used for processing recursively
  #  reduced subunits
  set numerflag 1
  set numerator [::list]
  set denominator [::list]
  
  set operations {}
  
  foreach subunit $unitString {
    #  Check for "/"
    if { "$subunit" == "/" } {
      set numerflag [expr {$numerflag?0:1}]
      continue
    }

    #  Constant factor
    if { [string is double -strict $subunit] } {
      if { $subunit == 0.0 } {
        error "illegal zero factor"
      } else {
        if { $numerflag } {
          set factor [expr {$factor * $subunit}]
        } else {
          set factor [expr {$factor / $subunit}]
        }
        continue
      }
    }
  
    #  Check for power string (e.g. "s^2")
    #  We could use regexp to match and split in one operation,
    #  like {([^\^]*)\^(.*)} but that seems to be pretty durn
    #  slow, so we'll just using [string] operations.
    if { [set index [string first "^" $subunit]] >= 0 } {
      set subunitname [string range $subunit 0 [expr {$index-1}]]
      set exponent [string range $subunit [expr {$index+1}] end]
      if { ! [string is integer -strict $exponent] } {
        error "invalid integer exponent"
      }
      #  This is a good test and error message, but it won't
      #  happen, because the negative sign (hypen) has already
      #  been interpreted as a unit separator.  Negative
      #  exponents will trigger the 'invalid integer' message,
      #  because there is no exponent. :-)
      if { $exponent < 1 } {
        error "invalid non-positive exponent"
      }
    } else {
        set subunitname $subunit
        set exponent 1
    }

    # Check subunit name syntax
    if { ! [string is alpha -strict $subunitname] } {
        error "invalid non-alphabetic unit name"
    }

    #  Try looking up the subunitname.  
    #
    #  Start with the unit name.  But if the unit ends in "s"
    #  or "es", then we want to try shortened (singular)
    #  versions of the subunit as well.
    set unitValue ""

    set subunitmatchlist [::list $subunitname]
    if { [string range $subunitname end end] == "s" } {
        lappend subunitmatchlist [string range $subunitname 0 end-1]
    }
    if { [string range $subunitname end-1 end] == "es" } {
        lappend subunitmatchlist [string range $subunitname 0 end-2]
    }

    foreach singularunit $subunitmatchlist {

      set len [string length $singularunit]

      #  Search the unit list in order, because we 
      #  wouldn't want to accidentally match the "m" 
      #  at the end of "gram" and conclude that we 
      #  have "meter".  
      foreach {name value} $UnitList {
    
        #  Try to match the string starting at the
        #  at the end, just in case there is a prefix.
        #  We only have a match if both the prefix and
        #  unit name are exact matches.
        set pos [expr {$len - [string length $name]}]
        #set pos [expr {$len-1}]
        if { [string range $singularunit $pos end] == $name } {

          set prefix [string range $singularunit 0 [expr {$pos-1}]]
          set matchsubunit $name
  
          #  If we have no prefix or a valid prefix, 
          #  then we've got an actual match.
          if { ("$prefix" == "") || \
            [info exists PrefixTable($prefix)] } {
            #  Set the unit value string
            set unitValue $value
            # done searching UnitList
            break
          }
        }
        # check for done 
        if { $unitValue != "" } {
            break
        }
      }
    }

    # Check for not-found
    if { "$unitValue" == "" } {
      error "invalid unit name '$subunitname'"
    }
  
    #  Multiply the factor by the prefix value
    if { "$prefix" != "" } { 
      #  Look up prefix value recursively, so abbreviations
      #  like "k" for "kilo" will work.  Note that we
      #  don't need error checking here (as we do for
      #  unit lookup) because we have total control over
      #  the prefix table.
      while { ! [string is double -strict $prefix] } {
        set prefix $PrefixTable($prefix)
      }
      # Save prefix multiple in factor
      set multiple [expr {pow($prefix,$exponent)}]
      if { $numerflag } {
        set factor [expr {$factor * $multiple}]
      } else {
        set factor [expr {$factor / $multiple}]
      }
    }

  
    # Is this a primitive subunit?
    if { "$unitValue" == "-primitive" } {
        # just append the matching subunit to the result
        # (this doesn't have prefix or trailing "s")
        for {set i 0} {$i<$exponent} {incr i} {
          if { $numerflag } {
            lappend numerator $matchsubunit
          } else {
            lappend denominator $matchsubunit
          }
        }
    } else {
      #  Recursively reduce, unless it is in the cache
      if { [info exists ::units::cache($unitValue)] } {
        set reducedUnit $::units::cache($unitValue)
      } else {
        set reducedUnit [::units::reduce $unitValue]
        set ::units::cache($unitValue) $reducedUnit
      }
      set opcode [lindex $reducedUnit 0]
      if {$opcode in {+ -}} {
        lappend operations {*}[_ReduceList_term $factor $numerator $denominator]
        if {$opcode eq "+"} {
          lappend operations -
        } else {
          lappend operations +  
        }
        set numerflag 1
        set numerator [::list]
        set denominator [::list]
        set factor 1.0
        set reducedUnit [lrange $reducedUnit 1 end]
      }     
      #  Include multiple factor from reduced unit
      set multiple [expr {pow([lindex $reducedUnit 0],$exponent)}]
      if { $numerflag } {
        set factor [expr {$factor * $multiple}]
      } else {
        set factor [expr {$factor / $multiple}]
      }

      #  Add primitive subunits to numerator/denominator
      #
      #  Note that we're use a nested boolean flag to switch
      #  between numerator and denominator.  Subunits in
      #  the numerator of the unitString are processed
      #  normally, but subunits in the denominator of
      #  unitString must be inverted.
      set numerflag2 $numerflag
      foreach u [lrange $reducedUnit 1 end] {
        if { "$u" == "/" } {
          set numerflag2 [expr {$numerflag2?0:1}]
          continue
        }
        #  Append the reduced units "exponent" times
        for {set i 0} {$i<$exponent} {incr i} {
          if { $numerflag2 } {
            lappend numerator $u
          } else {
            lappend denominator $u
          }
        }
      }
      
    }
  }
  lappend operations {*}[_ReduceList_term $factor $numerator $denominator]
  return $operations
}


#-----------------------------------------------------------------
#
#  Initialize namespace variables
#
#-----------------------------------------------------------------
namespace eval ::units {

    set PrefixList {
	yotta        1e24
	zetta        1e21
	exa          1e18
	peta         1e15
	tera         1e12
	giga         1e9
	mega         1e6
	kilo         1e3
	hecto        1e2
	deka         1e1
	deca         1e1
	deci         1e-1
	centi        1e-2
	milli        1e-3
	micro        1e-6
	nano         1e-9
	pico         1e-12
	femto        1e-15
	atto         1e-18
	zepto        1e-21
	yocto        1e-24
	Y            yotta
	Z            zetta
	E            exa
	P            peta
	T            tera
	G            giga
	M            mega
	k            kilo
	h            hecto
	da           deka
	d            deci
	c            centi
	m            milli
	u            micro
	n            nano
	p            pico
	f            femto
	a            atto
	z            zepto
	y            yocto
    }

    array set PrefixTable $PrefixList

    set SIunits {
	meter        -primitive
	gram         -primitive
	second       -primitive
	ampere       -primitive
	kelvin       -primitive
	mole         -primitive
	candela      -primitive
	radian       meter/meter
	steradian    meter^2/meter^2
	hertz        /second
	newton       meter-kilogram/second^2
	pascal       kilogram/meter-second^2
	joule        meter^2-kilogram/second^2
	watt         meter^2-kilogram/second^3
	coulomb      second-ampere
	volt         meter^2-kilogram/second^3-ampere
	farad        second^4-ampere^2/meter^2-kilogram
	ohm	     meter^2-kilogram/second^3-ampere^2
	siemens      second^3-ampere^2/meter^2-kilogram
	weber        meter^2-kilogram/second^2-ampere
	tesla        kilogram/second^2-ampere
	henry        meter^2-kilogram/second^2-ampere^2
	lumen        candela-steradian
	lux          candela-steradian/meter^2
	becquerel    /second
	gray         meter^2/second^2
	sievert      meter^2/second^2
    }
    set SIabbrevs {
	m            meter
	g            gram
	s            second
	A            ampere
	K            kelvin
	mol          mole
	cd           candela
	rad          radian
	sr           steradian
	Hz           hertz
	N            newton
	Pa           pascal
	J            joule
	W            watt
	C            coulomb
	V            volt
	F            farad
	S            siemens
	Wb           weber
	T            tesla
	H            henry
	lm           lumen
	lx           lux
	Bq           becquerel
	Gy           gray
	Sv           sievert
    }

    #  Selected non-SI units from Appendix B of the Guide for
    #  the use of the International System of Units
    set nonSIunits {
	angstrom              1.0E-10meter
	astronomicalUnit      1.495979E11meter
	atmosphere            1.01325E5pascal
	bar                   1.0E5pascal
	calorie               4.1868joule
	curie                 3.7E10becquerel
	day                   8.64E4second
	degree                1.745329E-2radian
	erg                   1.0E-7joule
	faraday               9.648531coulomb
	fermi                 1.0E-15meter
        foot                  3.048E-1meter
	gauss                 1.0E-4tesla
	gilbert               7.957747E-1ampere
	grain                 6.479891E-5kilogram
	hectare               1.0E4meter^2
	hour                  3.6E3second
	inch                  2.54E-2meter
	lightYear             9.46073E15meter
	liter                 1.0E-3meter^3
	maxwell               1.0E-8weber
	mho                   1.0siemens
	micron                1.0E-6meter
	mil                   2.54E-5meter
	mile                  1.609344E3meter
	minute                6.0E1second
	parsec                3.085E16meter
	pica                  4.233333E-3meter
	pound                 4.535924E-1kilogram
	revolution            6.283185radian
	revolutionPerMinute   1.047198E-1radian/second
	yard                  9.144E-1meter
	year                  3.1536E7second
    }
    set nonSIabbrevs {
	AU           astronomicalUnit
	ft           foot
	gr           grain
	ha           hectare
	h            hour
	in           inch
	L            liter
	Mx           maxwell
	mi           mile
	min          minute
	pc           parsec
	lb           pound
	r            revolution
	rpm          revolutionPerMinute
	yd           yard
    }

    foreach {name value} $SIunits {
	dict set UnitList $name $value
    }
    foreach {name value} $nonSIunits {
	dict set UnitList $name $value
    }
    foreach {name value} $SIabbrevs {
	dict set UnitList $name $value
    }
    foreach {name value} $nonSIabbrevs {
	dict set UnitList $name $value
    }
}
