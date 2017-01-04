# counter.tcl --
#
#   Procedures to manage simple counters and histograms.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: counter.tcl,v 1.23 2005/09/30 05:36:38 andreas_kupries Exp $

package require Tcl 8.2

namespace eval ::counter {

    # Variables of name counter::T-$tagname
    # are created as arrays to support each counter.

    # Time-based histograms are kept in sync with each other,
    # so these variables are shared among them.
    # These base times record the time corresponding to the first bucket 
    # of the per-minute, per-hour, and per-day time-based histograms.

    variable startTime
    variable minuteBase
    variable hourBase
    variable hourEnd
    variable dayBase
    variable hourIndex
    variable dayIndex

    # The time-based histogram uses an after event and a list
    # of counters to do mergeing on.

    variable tagsToMerge
    if {![info exists tagsToMerge]} {
    set tagsToMerge {}
    }
    variable mergeInterval

    namespace export init reset count exists get names start stop
    namespace export histHtmlDisplay histHtmlDisplayRow histHtmlDisplayBarChart
}

# ::counter::init --
#
#   Set up a counter.
#
# Arguments:
#   tag The identifier for the counter.  Pass this to counter::count
#   args    option values pairs that define characteristics of the counter:
#       See the man page for definitons.
#
# Results:
#   None.
#
# Side Effects:
#   Initializes state about a counter.

proc ::counter::init {tag args} {
    upvar #0 counter::T-$tag counter
    if {[info exists counter]} {
    unset counter
    }
    set counter(N) 0    ;# Number of samples
    set counter(total) 0
    set counter(type) {}

    # With an empty type the counter is a simple accumulator
    # for which we can compute an average.  Here we loop through
    # the args to determine what additional counter attributes
    # we need to maintain in counter::count

    foreach {option value} $args {
    switch -- $option {
        -timehist {
        variable tagsToMerge
        variable secsPerMinute
        variable startTime
        variable minuteBase
        variable hourBase
        variable dayBase
        variable hourIndex
        variable dayIndex

        upvar #0 counter::H-$tag histogram
        upvar #0 counter::Hour-$tag hourhist
        upvar #0 counter::Day-$tag dayhist

        # Clear the histograms.

        for {set i 0} {$i < 60} {incr i} {
            set histogram($i) 0
        }
        for {set i 0} {$i < 24} {incr i} {
            set hourhist($i) 0
        }
        if {[info exists dayhist]} {
            unset dayhist
        }
        set dayhist(0) 0

        # Clear all-time high records

        set counter(maxPerMinute) 0
        set counter(maxPerHour) 0
        set counter(maxPerDay) 0

        # The value associated with -timehist is the number of seconds
        # in each bucket.  Normally this is 60, but for
        # testing, we compress minutes.  The value is limited at
        # 60 because the per-minute buckets are accumulated into
        # per-hour buckets later.

        if {$value == "" || $value == 0 || $value > 60} {
            set value 60
        }

        # Histogram state variables.
        # All time-base histograms share the same bucket size
        # and starting times to keep them all synchronized.
        # So, we only initialize these parameters once.

        if {![info exists secsPerMinute]} {
            set secsPerMinute $value

            set startTime [clock seconds]
            set dayIndex 0

            set dayStart [clock scan [clock format $startTime \
                -format 00:00]]
            
            # Figure out what "hour" we are

            set delta [expr {$startTime - $dayStart}]
            set hourIndex [expr {$delta / ($secsPerMinute * 60)}]
            set day [expr {$hourIndex / 24}]
            set hourIndex [expr {$hourIndex % 24}]

            set hourBase [expr {$dayStart + $day * $secsPerMinute * 60 * 24}]
            set minuteBase [expr {$hourBase + $hourIndex * 60 * $secsPerMinute}]

            set partialHour [expr {$startTime -
            ($hourBase + $hourIndex * 60 * $secsPerMinute)}]
            set secs [expr {(60 * $secsPerMinute) - $partialHour}]
            if {$secs <= 0} {
            set secs 1
            }

            # After the first timer, the event occurs once each "hour"

            set mergeInterval [expr {60 * $secsPerMinute * 1000}]
            after [expr {$secs * 1000}] [list counter::MergeHour $mergeInterval]
        }
        if {[lsearch $tagsToMerge $tag] < 0} {
            lappend tagsToMerge $tag
        }

        # This records the last used slots in order to zero-out the
        # buckets that are skipped during idle periods.

        set counter(lastMinute) -1

        # The following is referenced when bugs cause histogram
        # hits outside the expect range (overflow and underflow)

        set counter(bucketsize)  0
        }
        -group {
        # Cluster a set of counters with a single total

        upvar #0 counter::H-$tag histogram
        if {[info exists histogram]} {
            unset histogram
        }
        set counter(group) $value
        }
        -lastn {
        # The lastN samples are kept if a vector to form a running average.

        upvar #0 counter::V-$tag vector
        set counter(lastn) $value
        set counter(index) 0
        if {[info exists vector]} {
            unset vector
        }
        for {set i 0} {$i < $value} {incr i} {
            set vector($i) 0
        }
        }
        -hist {
        # A value-based histogram with buckets for different values.

        upvar #0 counter::H-$tag histogram
        if {[info exists histogram]} {
            unset histogram
        }
        set counter(bucketsize) $value
        set counter(mult) 1
        }
        -hist2x {
        upvar #0 counter::H-$tag histogram
        if {[info exists histogram]} {
            unset histogram
        }
        set counter(bucketsize) $value
        set counter(mult) 2
        }
        -hist10x {
        upvar #0 counter::H-$tag histogram
        if {[info exists histogram]} {
            unset histogram
        }
        set counter(bucketsize) $value
        set counter(mult) 10
        }
        -histlog {
        upvar #0 counter::H-$tag histogram
        if {[info exists histogram]} {
            unset histogram
        }
        set counter(bucketsize) $value
        }
        -simple {
        # Useful when disabling predefined -timehist or -group counter
        }
        default {
        return -code error "Unsupported option $option.\
        Must be -timehist, -group, -lastn, -hist, -hist2x, -hist10x, -histlog, or -simple."
        }
    }
    if {[string length $option]} {
        # In case an option doesn't change the type, but
        # this feature of the interface isn't used, etc.

        lappend counter(type) $option
    }
    }

    # Instead of supporting a counter that could have multiple attributes,
    # we support a single type to make counting more efficient.

    if {[llength $counter(type)] > 1} {
    return -code error "Multiple type attributes not supported.  Use only one of\
        -timehist, -group, -lastn, -hist, -hist2x, -hist10x, -histlog, -disabled."
    }
    return ""
}

# ::counter::reset --
#
#   Reset a counter.
#
# Arguments:
#   tag The identifier for the counter.
#
# Results:
#   None.
#
# Side Effects:
#   Deletes the counter and calls counter::init again for it.

proc ::counter::reset {tag args} {
    upvar #0 counter::T-$tag counter

    # Layer reset on top of init.  Here we figure out what
    # we need to pass into the init procedure to recreate it.

    switch -- $counter(type) {
    ""  {
        set args ""
    }
    -group {
        upvar #0 counter::H-$tag histogram
        if {[info exists histogram]} {
        unset histogram
        }
        set args [list -group $counter(group)]
    }
    -lastn {
        upvar #0 counter::V-$tag vector
        if {[info exists vector]} {
        unset vector
        }
        set args [list -lastn $counter(lastn)]
    }
    -hist -
    -hist10x -
    -histlog -
    -hist2x {
        upvar #0 counter::H-$tag histogram
        if {[info exists histogram]} {
        unset histogram
        }
        set args [list $counter(type) $counter(bucketsize)]
    }
    -timehist {
        foreach h [list counter::H-$tag counter::Hour-$tag counter::Day-$tag] {
        upvar #0 $h histogram
        if {[info exists histogram]} {
            unset histogram
        }
        }
        set args [list -timehist $counter::secsPerMinute]
    }
    default {#ignore}
    }
    unset counter
    eval {counter::init $tag} $args
    set counter(resetDate) [clock seconds]
    return ""
}

# ::counter::count --
#
#   Accumulate statistics.
#
# Arguments:
#   tag The counter identifier.
#   delta   The increment amount.  Defaults to 1.
#   arg For -group types, this is the histogram index.
#
# Results:
#   None
#
# Side Effects:
#   Accumlate statistics.

proc ::counter::count {tag {delta 1} args} {
    upvar #0 counter::T-$tag counter
    set counter(total) [expr {$counter(total) + $delta}]
    incr counter(N)

    # Instead of supporting a counter that could have multiple attributes,
    # we support a single type to make counting a skosh more efficient.

#    foreach option $counter(type) {
    switch -- $counter(type) {
        ""  {
        # Simple counter
        return
        }
        -group {
        upvar #0 counter::H-$tag histogram
        set subIndex [lindex $args 0]
        if {![info exists histogram($subIndex)]} {
            set histogram($subIndex) 0
        }
        set histogram($subIndex) [expr {$histogram($subIndex) + $delta}]
        }
        -lastn {
        upvar #0 counter::V-$tag vector
        set vector($counter(index)) $delta
        set counter(index) [expr {($counter(index) +1)%$counter(lastn)}]
        }
        -hist {
        upvar #0 counter::H-$tag histogram
        set bucket [expr {int($delta / $counter(bucketsize))}]
        if {![info exists histogram($bucket)]} {
            set histogram($bucket) 0
        }
        incr histogram($bucket)
        }
        -hist10x -
        -hist2x {
        upvar #0 counter::H-$tag histogram
        set bucket 0
        for {set max $counter(bucketsize)} {$delta > $max} \
            {set max [expr {$max * $counter(mult)}]} {
            incr bucket
        }
        if {![info exists histogram($bucket)]} {
            set histogram($bucket) 0
        }
        incr histogram($bucket)
        }
        -histlog {
        upvar #0 counter::H-$tag histogram
        set bucket [expr {int(log($delta)*$counter(bucketsize))}]
        if {![info exists histogram($bucket)]} {
            set histogram($bucket) 0
        }
        incr histogram($bucket)
        }
        -timehist {
        upvar #0 counter::H-$tag histogram
        variable minuteBase
        variable secsPerMinute

        set minute [expr {([clock seconds] - $minuteBase) / $secsPerMinute}]
        if {$minute > 59} {
            # this occurs while debugging if the process is
            # stopped at a breakpoint too long.
            set minute 59
        }

        # Initialize the current bucket and 
        # clear any buckets we've skipped since the last sample.
        
        if {$minute != $counter(lastMinute)} {
            set histogram($minute) 0
            for {set i [expr {$counter(lastMinute)+1}]} \
                {$i < $minute} \
                {incr i} {
            set histogram($i) 0
            }
            set counter(lastMinute) $minute
        }
        set histogram($minute) [expr {$histogram($minute) + $delta}]
        }
        default {#ignore}
    }
#   }
    return
}

# ::counter::exists --
#
#   Return true if the counter exists.
#
# Arguments:
#   tag The counter identifier.
#
# Results:
#   1 if it has been defined.
#
# Side Effects:
#   None.

proc ::counter::exists {tag} {
    upvar #0 counter::T-$tag counter
    return [info exists counter]
}

# ::counter::get --
#
#   Return statistics.
#
# Arguments:
#   tag The counter identifier.
#   option  What statistic to get
#   args    Needed by some options.
#
# Results:
#   With no args, just the counter value.
#
# Side Effects:
#   None.

proc ::counter::get {tag {option -total} args} {
    upvar #0 counter::T-$tag counter
    switch -- $option {
    -total {
        return $counter(total)
    }
    -totalVar {
        return ::counter::T-$tag\(total)
    }
    -N {
        return $counter(N)
    }
    -avg {
        if {$counter(N) == 0} {
        return 0
        } else {
        return [expr {$counter(total) / double($counter(N))}]
        }
    }
    -avgn {
        if {$counter(type) != "-lastn"} {
        return -code error "The -avgn option is only supported for -lastn counters."
        }
        upvar #0 counter::V-$tag vector
        set sum 0
        for {set i 0} {($i < $counter(N)) && ($i < $counter(lastn))} {incr i} {
        set sum [expr {$sum + $vector($i)}]
        }
        if {$i == 0} {
        return 0
        } else {
        return [expr {$sum / double($i)}]
        }
    }
    -hist {
        upvar #0 counter::H-$tag histogram
        if {[llength $args]} {
        # Return particular bucket
        set bucket [lindex $args 0]
        if {[info exists histogram($bucket)]} {
            return $histogram($bucket)
        } else {
            return 0
        }
        } else {
        # Dump the whole histogram

        set result {}
        if {$counter(type) == "-group"} {
            set sort -dictionary
        } else {
            set sort -integer
        }
        foreach x [lsort $sort [array names histogram]] {
            lappend result $x $histogram($x)
        }
        return $result
        }
    }
    -histVar {
        return ::counter::H-$tag
    }
    -histHour {
        upvar #0 counter::Hour-$tag histogram
        set result {}
        foreach x [lsort -integer [array names histogram]] {
        lappend result $x $histogram($x)
        }
        return $result
    }
    -histHourVar {
        return ::counter::Hour-$tag
    }
    -histDay {
        upvar #0 counter::Day-$tag histogram
        set result {}
        foreach x [lsort -integer [array names histogram]] {
        lappend result $x $histogram($x)
        }
        return $result
    }
    -histDayVar {
        return ::counter::Day-$tag
    }
    -maxPerMinute {
        return $counter(maxPerMinute)
    }
    -maxPerHour {
        return $counter(maxPerHour)
    }
    -maxPerDay {
        return $counter(maxPerDay)
    }
    -resetDate {
        if {[info exists counter(resetDate)]} {
        return $counter(resetDate)
        } else {
        return ""
        }
    }
    -all {
        return [array get counter]
    }
    default {
        return -code error "Invalid option $option.\
        Should be -all, -total, -N, -avg, -avgn, -hist, -histHour,\
        -histDay, -totalVar, -histVar, -histHourVar, -histDayVar -resetDate."
    }
    }
}

# ::counter::names --
#
#   Return the list of defined counters.
#
# Arguments:
#   none
#
# Results:
#   A list of counter tags.
#
# Side Effects:
#   None.

proc ::counter::names {} {
    set result {}
    foreach v [info vars ::counter::T-*] {
    if {[info exists $v]} {
        # Declared arrays might not exist, yet
        # strip prefix from name
        set v [string range $v [string length "::counter::T-"] end]
        lappend result $v
    }
    }
    return $result
}

# ::counter::MergeHour --
#
#   Sum the per-minute histogram into the next hourly bucket.
#   On 24-hour boundaries, sum the hourly buckets into the next day bucket.
#   This operates on all time-based histograms.
#
# Arguments:
#   none
#
# Results:
#   none
#
# Side Effects:
#   See description.

proc ::counter::MergeHour {interval} {
    variable hourIndex
    variable minuteBase
    variable hourBase
    variable tagsToMerge
    variable secsPerMinute

    after $interval [list counter::MergeHour $interval]
    if {![info exists hourBase] || $hourIndex == 0} {
    set hourBase $minuteBase
    }
    set minuteBase [clock seconds]

    foreach tag $tagsToMerge {
    upvar #0 counter::T-$tag counter
    upvar #0 counter::H-$tag histogram
    upvar #0 counter::Hour-$tag hourhist

    # Clear any buckets we've skipped since the last sample.

    for {set i [expr {$counter(lastMinute)+1}]} {$i < 60} {incr i} {
        set histogram($i) 0
    }
    set counter(lastMinute) -1

    # Accumulate into the next hour bucket.

    set hourhist($hourIndex) 0
    set max 0
    foreach i [array names histogram] {
        set hourhist($hourIndex) [expr {$hourhist($hourIndex) + $histogram($i)}]
        if {$histogram($i) > $max} {
        set max $histogram($i)
        }
    }
    set perSec [expr {$max / $secsPerMinute}]
    if {$perSec > $counter(maxPerMinute)} {
        set counter(maxPerMinute) $perSec
    }
    }
    set hourIndex [expr {($hourIndex + 1) % 24}]
    if {$hourIndex == 0} {
    counter::MergeDay
    }

}
# ::counter::MergeDay --
#
#   Sum the per-minute histogram into the next hourly bucket.
#   On 24-hour boundaries, sum the hourly buckets into the next day bucket.
#   This operates on all time-based histograms.
#
# Arguments:
#   none
#
# Results:
#   none
#
# Side Effects:
#   See description.

proc ::counter::MergeDay {} {
    variable dayIndex
    variable dayBase
    variable hourBase
    variable tagsToMerge
    variable secsPerMinute

    # Save the hours histogram into a bucket for the last day
    # counter(day,$day) is the starting time for that day bucket

    if {![info exists dayBase]} {
    set dayBase $hourBase
    }
    foreach tag $tagsToMerge {
    upvar #0 counter::T-$tag counter
    upvar #0 counter::Day-$tag dayhist
    upvar #0 counter::Hour-$tag hourhist
    set dayhist($dayIndex) 0
    set max 0
    for {set i 0} {$i < 24} {incr i} {
        if {[info exists hourhist($i)]} {
        set dayhist($dayIndex) [expr {$dayhist($dayIndex) + $hourhist($i)}]
        if {$hourhist($i) > $max} { 
            set max $hourhist($i) 
        }
        }
    }
    set perSec [expr {double($max) / ($secsPerMinute * 60)}]
    if {$perSec > $counter(maxPerHour)} {
        set counter(maxPerHour) $perSec
    }
    }
    set perSec [expr {double($dayhist($dayIndex)) / ($secsPerMinute * 60 * 24)}]
    if {$perSec > $counter(maxPerDay)} {
    set counter(maxPerDay) $perSec
    }
    incr dayIndex
}

# ::counter::histHtmlDisplay --
#
#   Create an html display of the histogram.
#
# Arguments:
#   tag The counter tag
#   args    option, value pairs that affect the display:
#       -title  Label to display above bar chart
#       -unit   minutes, hours, or days select time-base histograms.
#           Specify anything else for value-based histograms.
#       -images URL of /images directory.
#       -gif    Image for normal histogram bars
#       -ongif  Image for the active histogram bar
#       -max    Maximum number of value-based buckets to display
#       -height Pixel height of the highest bar
#       -width  Pixel width of each bar
#       -skip   Buckets to skip when labeling value-based histograms
#       -format Format used to display labels of buckets.
#       -text   If 1, a text version of the histogram is dumped,
#           otherwise a graphical one is generated.
#
# Results:
#   HTML for the display as a complete table.
#
# Side Effects:
#   None.

proc ::counter::histHtmlDisplay {tag args} {
    append result "<p>\n<table border=0 cellpadding=0 cellspacing=0>\n"
    append result [eval {counter::histHtmlDisplayRow $tag} $args]
    append result </table>
    return $result
}

# ::counter::histHtmlDisplayRow --
#
#   Create an html display of the histogram.
#
# Arguments:
#   See counter::histHtmlDisplay
#
# Results:
#   HTML for the display.  Ths is one row of a 2-column table,
#   the calling page must define the <table> tag.
#
# Side Effects:
#   None.

proc ::counter::histHtmlDisplayRow {tag args} {
    upvar #0 counter::T-$tag counter
    variable secsPerMinute
    variable minuteBase
    variable hourBase
    variable dayBase
    variable hourIndex
    variable dayIndex

    array set options [list \
    -title  $tag \
    -unit   "" \
    -images /images \
    -gif    Blue.gif \
    -ongif  Red.gif \
    -max    -1 \
    -height 100 \
    -width  4 \
    -skip   4 \
    -format %.2f \
    -text   0
    ]
    array set options $args

    # Support for self-posting pages that can clear counters.

    append result "<!-- resetCounter [ncgi::value resetCounter] -->"
    if {[ncgi::value resetCounter] == $tag} {
    counter::reset $tag
    return "<!-- Reset $tag counter -->"
    }

    switch -glob -- $options(-unit) {
    min* {
        upvar #0 counter::H-$tag histogram
        set histname counter::H-$tag
        if {![info exists minuteBase]} {
        return "<!-- No time-based histograms defined -->"
        }
        set time $minuteBase
        set secsForMax $secsPerMinute
        set periodMax $counter(maxPerMinute)
        set curIndex [expr {([clock seconds] - $minuteBase) / $secsPerMinute}]
        set options(-max) 60
        set options(-min) 0
    }
    hour* {
        upvar #0 counter::Hour-$tag histogram
        set histname counter::Hour-$tag
        if {![info exists hourBase]} {
        return "<!-- Hour merge has not occurred -->"
        }
        set time $hourBase
        set secsForMax [expr {$secsPerMinute * 60}]
        set periodMax $counter(maxPerHour)
        set curIndex [expr {$hourIndex - 1}]
        if {$curIndex < 0} {
        set curIndex 23
        }
        set options(-max) 24
        set options(-min) 0
    }
    day* {
        upvar #0 counter::Day-$tag histogram
        set histname counter::Day-$tag
        if {![info exists dayBase]} {
        return "<!-- Hour merge has not occurred -->"
        }
        set time $dayBase
        set secsForMax [expr {$secsPerMinute * 60 * 24}]
        set periodMax $counter(maxPerDay)
        set curIndex dayIndex
        set options(-max) $dayIndex
        set options(-min) 0
    }
    default {
        # Value-based histogram with arbitrary units.

        upvar #0 counter::H-$tag histogram
        set histname counter::H-$tag

        set unit $options(-unit)
        set curIndex ""
        set time ""
    }
    }
    if {! [info exists histogram]} {
    return "<!-- $histname doesn't exist -->\n"
    }

    set max 0
    set maxName 0
    foreach {name value} [array get histogram] {
    if {$value > $max} {
        set max $value
        set maxName $name
    }
    }

    # Start 2-column HTML display.  A summary table at the left, the histogram on the right.

    append result "<tr><td valign=top>\n"

    append result "<table bgcolor=#EEEEEE>\n"
    append result "<tr><td colspan=2 align=center>[html::font]<b>$options(-title)</b></font></td></tr>\n"
    append result "<tr><td>[html::font]<b>Total</b></font></td>"
    append result "<td>[html::font][format $options(-format) $counter(total)]</font></td></tr>\n"

    if {[info exists secsForMax]} {

    # Time-base histogram

    set string {}
    set t $secsForMax
    set days [expr {$t / (60 * 60 * 24)}]
    if {$days == 1} {
        append string "1 Day "
    } elseif {$days > 1} {
        append string "$days Days "
    }
    set t [expr {$t - $days * (60 * 60 * 24)}]
    set hours [expr {$t / (60 * 60)}]
    if {$hours == 1} {
        append string "1 Hour "
    } elseif {$hours > 1} {
        append string "$hours Hours "
    }
    set t [expr {$t - $hours * (60 * 60)}]
    set mins [expr {$t / 60}]
    if {$mins == 1} {
        append string "1 Minute "
    } elseif {$mins > 1} {
        append string "$mins Minutes "
    }
    set t [expr {$t - $mins * 60}]
    if {$t == 1} {
        append string "1 Second "
    } elseif {$t > 1} {
        append string "$t Seconds "
    }
    append result "<tr><td>[html::font]<b>Bucket Size</b></font></td>"
    append result "<td>[html::font]$string</font></td></tr>\n"

    append result "<tr><td>[html::font]<b>Max Per Sec</b></font></td>"
    append result "<td>[html::font][format %.2f [expr {$max/double($secsForMax)}]]</font></td></tr>\n"

    if {$periodMax > 0} {
        append result "<tr><td>[html::font]<b>Best Per Sec</b></font></td>"
        append result "<td>[html::font][format %.2f $periodMax]</font></td></tr>\n"
    }
    append result "<tr><td>[html::font]<b>Starting Time</b></font></td>"
    switch -glob -- $options(-unit) {
        min* {
        append result "<td>[html::font][clock format $time \
            -format %k:%M:%S]</font></td></tr>\n"
        }
        hour* {
        append result "<td>[html::font][clock format $time \
            -format %k:%M:%S]</font></td></tr>\n"
        }
        day* {
        append result "<td>[html::font][clock format $time \
            -format "%b %d %k:%M"]</font></td></tr>\n"
        }
        default {#ignore}
    }

    } else {

    # Value-base histogram

    set ix [lsort -integer [array names histogram]]

    set mode [expr {$counter(bucketsize) * $maxName}]
    set first [expr {$counter(bucketsize) * [lindex $ix 0]}]
    set last [expr {$counter(bucketsize) * [lindex $ix end]}]

    append result "<tr><td>[html::font]<b>Average</b></font></td>"
    append result "<td>[html::font][format $options(-format) [counter::get $tag -avg]]</font></td></tr>\n"

    append result "<tr><td>[html::font]<b>Mode</b></font></td>"
    append result "<td>[html::font]$mode</font></td></tr>\n"

    append result "<tr><td>[html::font]<b>Minimum</b></font></td>"
    append result "<td>[html::font]$first</font></td></tr>\n"

    append result "<tr><td>[html::font]<b>Maximum</b></font></td>"
    append result "<td>[html::font]$last</font></td></tr>\n"

    append result "<tr><td>[html::font]<b>Unit</b></font></td>"
    append result "<td>[html::font]$unit</font></td></tr>\n"

    append result "<tr><td colspan=2 align=center>[html::font]<b>"
    append result "<a href=[ncgi::urlStub]?resetCounter=$tag>Reset</a></td></tr>\n"

    if {$options(-max) < 0} {
        set options(-max) [lindex $ix end]
    }
    if {![info exists options(-min)]} {
        set options(-min) [lindex $ix 0]
    }
    }

    # End table nested inside left-hand column

    append result </table>\n
    append result </td>\n
    append result "<td valign=bottom>\n"


    # Display the histogram

    if {$options(-text)} {
    } else {
    append result [eval \
        {counter::histHtmlDisplayBarChart $tag histogram $max $curIndex $time} \
        [array get options]]
    }

    # Close the right hand column, but leave our caller's table open.

    append result </td></tr>\n

    return $result
}

# ::counter::histHtmlDisplayBarChart --
#
#   Create an html display of the histogram.
#
# Arguments:
#   tag     The counter tag.
#   histVar     The name of the histogram array
#   max     The maximum counter value in a histogram bucket.
#   curIndex    The "current" histogram index, for time-base histograms.
#   time        The base, or starting time, for the time-based histograms.
#   args        The array get of the options passed into histHtmlDisplay
#
# Results:
#   HTML for the bar chart.
#
# Side Effects:
#   See description.

proc ::counter::histHtmlDisplayBarChart {tag histVar max curIndex time args} {
    upvar #0 counter::T-$tag counter
    upvar 1 $histVar histogram
    variable secsPerMinute
    array set options $args

    append result "<table cellpadding=0 cellspacing=0 bgcolor=#eeeeee><tr>\n"

    set ix [lsort -integer [array names histogram]]

    for {set t $options(-min)} {$t < $options(-max)} {incr t} {
    if {![info exists histogram($t)]} {
        set value 0
    } else {
        set value $histogram($t)
    }
    if {$max == 0 || $value == 0} {
        set height 1
    } else {
        set percent [expr {round($value * 100.0 / $max)}]
        set height [expr {$percent * $options(-height) / 100}]
    }
    if {$t == $curIndex} {
        set img src=$options(-images)/$options(-ongif)
    } else {
        set img src=$options(-images)/$options(-gif)
    }
    append result "<td valign=bottom><img $img height=$height\
        width=$options(-width) title=$value alt=$value></td>\n"
    }
    append result "</tr>"

    # Count buckets outside the range requested

    set overflow 0
    set underflow 0
    foreach t [lsort -integer [array names histogram]] {
    if {($options(-max) > 0) && ($t > $options(-max))} {
        incr overflow
    }
    if {($options(-min) >= 0) && ($t < $options(-min))} {
        incr underflow
    }
    }

    # Append a row of labels at the bottom.

    set colors {black #CCCCCC}
    set bgcolors {#CCCCCC black}
    set colori 0
    if {$counter(type) != "-timehist"} {

    # Label each bucket with its value
    # This is probably wrong for hist2x and hist10x

    append result "<tr>"
    set skip $options(-skip)
    if {![info exists counter(mult)]} {
        set counter(mult) 1
    }

    # These are tick marks

    set img src=$options(-images)/$options(-gif)
    append result "<tr>"
    for {set i $options(-min)} {$i < $options(-max)} {incr i} {
        if {(($i % $skip) == 0)} {
        append result "<td valign=bottom><img $img height=3 \
            width=1></td>\n"
        } else {
        append result "<td valign=bottom></td>"
        }
    }
    append result </tr>

    # These are the labels

    append result "<tr>"
    for {set i $options(-min)} {$i < $options(-max)} {incr i} {
        if {$counter(type) == "-histlog"} {
        if {[catch {expr {int(log($i) * $counter(bucketsize))}} x]} {
            # Out-of-bounds
            break
        }
        } else {
        set x [expr {$i * $counter(bucketsize) * $counter(mult)}]
        }
        set label [format $options(-format) $x]
        if {(($i % $skip) == 0)} {
        set color [lindex $colors $colori]
        set bg [lindex $bgcolors $colori]
        set colori [expr {($colori+1) % 2}]
        append result "<td colspan=$skip><font size=1 color=$color>$label</font></td>"
        }
    }
    append result </tr>
    } else {
    switch -glob -- $options(-unit) {
        min*    {
        if {$secsPerMinute != 60} {
            set format %k:%M:%S
            set skip 12
        } else {
            set format %k:%M
            set skip 4
        }
        set deltaT $secsPerMinute
        set wrapDeltaT [expr {$secsPerMinute * -59}]
        }
        hour*   {
        if {$secsPerMinute != 60} {
            set format %k:%M
            set skip 4
        } else {
            set format %k
            set skip 2
        }
        set deltaT [expr {$secsPerMinute * 60}]
        set wrapDeltaT [expr {$secsPerMinute * 60 * -23}]
        }
        day* {
        if {$secsPerMinute != 60} {
            set format "%m/%d %k:%M"
            set skip 10
        } else {
            set format %k
            set skip $options(-skip)
        }
        set deltaT [expr {$secsPerMinute * 60 * 24}]
        set wrapDeltaT 0
        }
        default {#ignore}
    }
    # These are tick marks

    set img src=$options(-images)/$options(-gif)
    append result "<tr>"
    foreach t [lsort -integer [array names histogram]] {
        if {(($t % $skip) == 0)} {
        append result "<td valign=bottom><img $img height=3 \
            width=1></td>\n"
        } else {
        append result "<td valign=bottom></td>"
        }
    }
    append result </tr>

    set lastLabel ""
    append result "<tr>"
    foreach t [lsort -integer [array names histogram]] {

        # Label each bucket with its time

        set label [clock format $time -format $format]
        if {(($t % $skip) == 0) && ($label != $lastLabel)} {
        set color [lindex $colors $colori]
        set bg [lindex $bgcolors $colori]
        set colori [expr {($colori+1) % 2}]
        append result "<td colspan=$skip><font size=1 color=$color>$label</font></td>"
        set lastLabel $label
        }
        if {$t == $curIndex} {
        incr time $wrapDeltaT
        } else {
        incr time $deltaT
        }
    }
    append result </tr>\n
    }
    append result "</table>"
    if {$underflow > 0} {
    append result "<br>Skipped $underflow samples <\
        [expr {$options(-min) * $counter(bucketsize)}]\n"
    }
    if {$overflow > 0} {
    append result "<br>Skipped $overflow samples >\
        [expr {$options(-max) * $counter(bucketsize)}]\n"
    }
    return $result
}

# ::counter::start --
#
#   Start an interval timer.  This should be pre-declared with
#   type either -hist, -hist2x, or -hist20x
#
# Arguments:
#   tag     The counter identifier.
#   instance    There may be multiple intervals outstanding
#           at any time.  This serves to distinquish them.
#
# Results:
#   None
#
# Side Effects:
#   Records the starting time for the instance of this interval.

proc ::counter::start {tag instance} {
    upvar #0 counter::Time-$tag time
    # clock clicks can return negative values if the sign bit is set
    # Here we turn it into a 31-bit counter because we only want
    # relative differences
    set msec [expr {[clock clicks -milliseconds] & 0x7FFFFFFF}]
    set time($instance) [list $msec [clock seconds]]
}

# ::counter::stop --
#
#   Record an interval timer.
#
# Arguments:
#   tag     The counter identifier.
#   instance    There may be multiple intervals outstanding
#           at any time.  This serves to distinquish them.
#   func        An optional function used to massage the time
#           stamp before putting into the histogram.
#
# Results:
#   None
#
# Side Effects:
#   Computes the current interval and adds it to the histogram.

proc ::counter::stop {tag instance {func ::counter::Identity}} {
    upvar #0 counter::Time-$tag time

    if {![info exists time($instance)]} {
	# Extra call. Ignore so we can debug error cases.
	return
    }
    set msec [expr {[clock clicks -milliseconds] & 0x7FFFFFFF}]
    set now [list $msec [clock seconds]]
    set delMicros [expr {[lindex $now 0] - [lindex $time($instance) 0]}]
    if {$delMicros < 0} {
      # Microsecond counter wrapped.
      set delMicros [expr {0x7FFFFFFF - [lindex $time($instance) 0] +
                            [lindex $now 0]}]
    }
    set delSecond [expr {[lindex $now 1] - [lindex $time($instance) 1]}]
    unset time($instance)

    # It is quite possible that the millisecond counter is much
    # larger than 1000, so we just use it unless our microsecond
    # calculation is screwed up.

    if {$delMicros >= 0} {
      counter::count $tag [$func [expr {$delMicros / 1000.0}]]
    } else {
      counter::count $tag [$func $delSecond]
    }
}

# ::counter::Identity --
#
#   Return its argument.  This is used as the default function
#   to apply to an interval timer.
#
# Arguments:
#   x       Some value.
#
# Results:
#   $x
#
# Side Effects:
#   None


proc ::counter::Identity {x} {
    return $x
}

package provide counter 2.0.4
