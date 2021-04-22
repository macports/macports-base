# S3.tcl
#
###Abstract
# This presents an interface to Amazon's S3 service.
# The Amazon S3 service allows for reliable storage
# and retrieval of data via HTTP.
#
# Copyright (c) 2006,2008 Darren New. All Rights Reserved.
#
###Copyright
# NO WARRANTIES OF ANY TYPE ARE PROVIDED.
# COPYING OR USE INDEMNIFIES THE AUTHOR IN ALL WAYS.
#
# This software is licensed under essentially the same
# terms as Tcl. See LICENSE.txt for the terms.
#
###Revision String
# SCCS: %Z% %M% %I% %E% %U%
#
###Change history:
# 0.7.2 - added -default-bucket.
# 0.8.0 - fixed bug in getLocal using wrong prefix.
#         Upgraded to Tcl 8.5 release version.
# 1.0.0 - added SetAcl, GetAcl, and -acl keep option.
#

package require Tcl 8.5

# This is by Darren New too.
# It is a SAX package to format XML for easy retrieval.
# It should be in the same distribution as S3.
package require xsxp

# These three are required to do the auth, so always require them.
#    Note that package registry and package fileutil are required
#    by the individual routines that need them. Grep for "package".
package require sha1
package require md5
package require base64

package provide S3 1.0.3

namespace eval S3 {
    variable config          ; # A dict holding the current configuration.
    variable config_orig     ; # Holds configuration to "reset" back to.
    variable debug 0         ; # Turns on or off S3::debug
    variable debuglog 0      ; # Turns on or off debugging into a file
    variable bgvar_counter 0 ; # Makes unique names for bgvars.

    set config_orig [dict create \
        -reset false \
        -retries 3 \
        -accesskeyid "" -secretaccesskey "" \
	-service-access-point "s3.amazonaws.com" \
        -slop-seconds 3 \
	-use-tls false \
        -bucket-prefix "TclS3" \
	-default-compare "always" \
	-default-separator "/" \
	-default-acl "" \
	-default-bucket "" \
	]

    set config $config_orig
}

# Internal, for development. Print a line, and maybe log it.
proc S3::debuglogline {line} {
    variable debuglog
    puts $line
    if {$debuglog} {
	set x [open debuglog.txt a]
	puts $x $line
	close $x
    }
}

# Internal, for development. Print debug info properly formatted.
proc S3::debug {args} {
    variable debug
    variable debuglog
    if {!$debug} return
    set res ""
    if {"-hex" == [lindex $args 0]} {
	set str [lindex $args 1]
	foreach ch [split $str {}] {
	    scan $ch %c val
	    append res [format %02x $val]
	    append res " "
	}
	debuglogline $res
	return
    }
    if {"-dict" == [lindex $args 0]} {
	set dict [lindex $args 1]
	debuglogline "DEBUG dict:"
	foreach {key val} $dict {
	    set val [string map [list \
		\r \\r \n \\n \0 \\0 ] $val]
	    debuglogline "$key=$val"
	}
	return
    }
    set x [string map [list \
        \r \\r \n \\n \0 \\0 ] $args]
    debuglogline "DEBUG: $x"
}

# Internal. Throws an error if keys have not been initialized.
proc S3::checkinit {} {
    variable config
    set error "S3 must be initialized with -accesskeyid and -secretaccesskey before use"
    set e1 {S3 usage -accesskeyid "S3 identification not initialized"}
    set e2 {S3 usage -secretaccesskey "S3 identification not initialized"}
    if {[dict get $config -accesskeyid] eq ""} {
	error $error "" $e1
    }
    if {[dict get $config -secretaccesskey] eq ""} {
	error $error "" $e2
    }
}

# Internal. Calculates the Content-Type for a given file name.
# Naturally returns application/octet-stream if anything goes wrong.
proc S3::contenttype {fname} {
    if {$::tcl_platform(platform) == "windows"} {
	set extension [file extension $fname]
	uplevel #0 package require registry
	set key "\\\\HKEY_CLASSES_ROOT\\"
	set key "HKEY_CLASSES_ROOT\\"
	if {"." != [string index $extension 0]} {append key .}
	append key $extension
	set ct "application/octet-stream"
	if {$extension != ""} {
	    catch {set ct [registry get $key {Content Type}]} caught
	}
    } else {
	# Assume something like Unix.
	if {[file readable /etc/mime.types]} {
	    set extension [string trim [file extension $fname] "."]
	    set f [open /etc/mime.types r]
	    while {-1 != [gets $f line] && ![info exists c]} {
		set line [string trim $line]
		if {[string match "#*" $line]} continue
		if {0 == [string length $line]} continue
		set items [split $line]
		for {set i 1} {$i < [llength $items]} {incr i} {
		    if {[lindex $items $i] eq $extension} {
			set c [lindex $items 0]
			break
		    }
		}
	    }
	    close $f
	    if {![info exists c]} {
		set ct "application/octet-stream"
	    } else {
		set ct [string trim $c]
	    }
	} else {
	    # No /etc/mime.types here.
	    if {[catch {exec file -i $fname} res]} {
		set ct "application/octet-stream"
	    } else {
		set ct [string range $res [expr {1+[string first : $res]}] end]
		if {-1 != [string first ";" $ct]} {
		    set ct [string range $ct 0 [string first ";" $ct]]
		}
		set ct [string trim $ct "; "]
	    }
	}
    }
    return $ct
}

# Change current configuration. Not object-oriented, so only one
# configuration is tracked per interpreter.
proc S3::Configure {args} {
    variable config
    variable config_orig
    if {[llength $args] == 0} {return $config}
    if {[llength $args] == 1 && ![dict exists $config [lindex $args 0]]} {
	error "Bad option \"[lindex $args 0]\": must be [join [dict keys $config] ,\  ]" "" [list S3 usage [lindex $args 0] "Bad option to config"]
    }
    if {[llength $args] == 1} {return [dict get $config [lindex $args 0]]}
    if {[llength $args] % 2 != 0} {
	error "Config args must be -name val -name val" "" [list S3 usage [lindex $args end] "Odd number of config args"]
    }
    set new $config
    foreach {tag val} $args {
	if {![dict exists $new $tag]} {
	    error "Bad option \"$tag\": must be [join [dict keys $config] ,\  ]" "" [list S3 usage $tag "Bad option to config"]
	}
	dict set new $tag $val
	if {$tag eq "-reset" && $val} {
	    set new $config_orig
	}
    }
    if {[dict get $config -use-tls]} {
	error "TLS for S3 not yet implemented!" "" \
	    [list S3 notyet -use-tls $config]
    }
    set config $new ; # Only update if all went well
    return $config
}

# Suggest a unique bucket name based on usename and config info.
proc S3::SuggestBucket {{usename ""}} {
    checkinit
    if {$usename eq ""} {set usename [::S3::Configure -bucket-prefix]}
    if {$usename eq ""} {
	error "S3::SuggestBucket requires name or -bucket-prefix set" \
	"" [list S3 usage -bucket-prefix]
    }
    return $usename\.[::S3::Configure -accesskeyid]
}

# Calculate authorization token for REST interaction.
# Doesn't work yet for "Expires" type headers. Hence, only for "REST".
# We specifically don't call checkinit because it's called in all
# callers and we don't want to throw an error inside here.
# Caveat Emptor if you expect otherwise.
# This is internal, but useful enough you might want to invoke it.
proc S3::authREST {verb resource content-type headers args} {
    if {[llength $args] != 0} {
	set body [lindex $args 0] ; # we use [info exists] later
    }
    if {${content-type} != "" && [dict exists $headers content-type]} {
	set content-type [dict get $headers content-type]
    }
    dict unset headers content-type
    set verb [string toupper $verb]
    if {[info exists body]} {
	set content-md5 [::base64::encode [::md5::md5 $body]]
	dict set headers content-md5 ${content-md5}
	dict set headers content-length [string length $body]
    } elseif {[dict exists $headers content-md5]} {
	set content-md5 [dict get $headers content-md5]
    } else {
	set content-md5 ""
    }
    if {[dict exists $headers x-amz-date]} {
	set date ""
	dict unset headers date
    } elseif {[dict exists $headers date]} {
	set date [dict get $headers date]
    } else {
	set date [clock format [clock seconds] -gmt true -format \
	    "%a, %d %b %Y %T %Z"]
	dict set headers date $date
    }
    if {${content-type} != ""} {
	dict set headers content-type ${content-type}
    }
    dict set headers host s3.amazonaws.com
    set xamz ""
    foreach key [lsort [dict keys $headers x-amz-*]] {
	# Assume each is seen only once, for now, and is canonical already.
        append xamz \n[string trim $key]:[string trim [dict get $headers $key]]
    }
    set xamz [string trim $xamz]
    # Hmmm... Amazon lies. No \n after xamz if xamz is empty.
    if {0 != [string length $xamz]} {append xamz \n}
    set signthis \
        "$verb\n${content-md5}\n${content-type}\n$date\n$xamz$resource"
    S3::debug "Sign this:" $signthis ; S3::debug -hex $signthis
    set sig [::sha1::hmac [S3::Configure -secretaccesskey] $signthis]
    set sig [binary format H* $sig]
    set sig [string trim [::base64::encode $sig]]
    dict set headers authorization "AWS [S3::Configure -accesskeyid]:$sig"
    return $headers
}

# Internal. Takes resource and parameters, tacks them together.
# Useful enough you might want to invoke it yourself.
proc S3::to_url {resource parameters} {
    if {0 == [llength $parameters]} {return $resource}
    if {-1 == [string first "?" $resource]} {
	set front ?
    } else {
	set front &
    }
    foreach {key value} $parameters {
	append resource $front $key "=" $value
	set front &
    }
    return $resource
}

# Internal. Encode a URL, including utf-8 versions.
# Useful enough you might want to invoke it yourself.
proc S3::encode_url {orig} {
    set res ""
    set re {[-a-zA-Z0-9/.,_]}
    foreach ch [split $orig ""] {
	if {[regexp $re $ch]} {
	    append res $ch
	} else {
	    foreach uch [split [encoding convertto utf-8 $ch] ""] {
		append res "%"
		binary scan $uch H2 hex
		append res $hex
	    }
	}
    }
    if {$res ne $orig} {
	S3::debug "URL Encoded:" $orig $res
    }
    return $res
}

# This is used internally to either queue an event-driven
# item or to simply call the next routine, depending on
# whether the current transaction is supposed to be running
# in the background or not.
proc S3::nextdo {routine thunk direction args} {
    global errorCode
    S3::debug "nextdo" $routine $thunk $direction $args
    if {[dict get $thunk blocking]} {
	return [S3::$routine $thunk]
    } else {
	if {[llength $args] == 2} {
	    # fcopy failed!
	    S3::fail $thunk "S3 fcopy failed: [lindex $args 1]" "" \
		[list S3 socket $errorCode]
	} else {
	    fileevent [dict get $thunk S3chan] $direction \
		[list S3::$routine $thunk]
	    if {$direction == "writable"} {
		fileevent [dict get $thunk S3chan] readable {}
	    } else {
		fileevent [dict get $thunk S3chan] writable {}
	    }
	}
    }
}

# The proverbial It.  Do a REST call to Amazon S3 service.
proc S3::REST {orig} {
    variable config
    checkinit
    set EndPoint [dict get $config -service-access-point]

    # Save the original stuff first.
    set thunk [dict create orig $orig]

    # Now add to thunk's top-level the important things
    if {[dict exists $thunk orig resultvar]} {
	dict set thunk blocking 0
    } else {
	dict set thunk blocking 1
    }
    if {[dict exists $thunk orig S3chan]} {
	dict set thunk S3chan [dict get $thunk orig S3chan]
    } elseif {[dict get $thunk blocking]} {
	dict set thunk S3chan [socket $EndPoint 80]
    } else {
	dict set thunk S3chan [socket -async $EndPoint 80]
    }
    fconfigure [dict get $thunk S3chan] -translation binary -encoding binary

    dict set thunk verb [dict get $thunk orig verb]
    dict set thunk resource [S3::encode_url [dict get $thunk orig resource]]
    if {[dict exists $orig rtype]} {
	dict set thunk resource \
	    [dict get $thunk resource]?[dict get $orig rtype]
    }
    if {[dict exists $orig headers]} {
	dict set thunk headers [dict get $orig headers]
    } else {
	dict set thunk headers [dict create]
    }
    if {[dict exists $orig infile]} {
	dict set thunk infile [dict get $orig infile]
    }
    if {[dict exists $orig content-type]} {
	dict set thunk content-type [dict get $orig content-type]
    } else {
	if {[dict exists $thunk infile]} {
	    set zz [dict get $thunk infile]
	} else {
	    set zz [dict get $thunk resource]
	}
	if {-1 != [string first "?" $zz]} {
	    set zz [string range $zz 0 [expr {[string first "?" $zz]-1}]]
	    set zz [string trim $zz]
	}
	if {$zz != ""} {
	    catch {dict set thunk content-type [S3::contenttype $zz]}
	} else {
	    dict set thunk content-type application/octet-stream
	    dict set thunk content-type ""
	}
    }
    set p {}
    if {[dict exist $thunk orig parameters]} {
	set p [dict get $thunk orig parameters]
    }
    dict set thunk url [S3::to_url [dict get $thunk resource] $p]

    if {[dict exists $thunk orig inbody]} {
        dict set thunk headers [S3::authREST \
            [dict get $thunk verb] [dict get $thunk resource] \
            [dict get $thunk content-type] [dict get $thunk headers] \
	    [dict get $thunk orig inbody] ]
    } else {
        dict set thunk headers [S3::authREST \
            [dict get $thunk verb] [dict get $thunk resource] \
            [dict get $thunk content-type] [dict get $thunk headers] ]
    }
    # Not the best place to put this code.
    if {![info exists body] && [dict exists $thunk infile]} {
	set size [file size [dict get $thunk infile]]
	set x [dict get $thunk headers]
	dict set x content-length $size
	dict set thunk headers $x
    }


    # Ready to go!
    return [S3::nextdo send_headers $thunk writable]
}

# Internal. Send the headers to Amazon. Might block if you have
# really small socket buffers, but Amazon doesn't want
# data that big anyway.
proc S3::send_headers {thunk} {
    S3::debug "Send-headers" $thunk
    set s3 [dict get $thunk S3chan]
    puts $s3 "[dict get $thunk verb] [dict get $thunk url] HTTP/1.0"
    S3::debug ">> [dict get $thunk verb] [dict get $thunk url] HTTP/1.0"
    foreach {key val} [dict get $thunk headers] {
	puts $s3 "$key: $val"
	S3::debug ">> $key: $val"
    }
    puts $s3 ""
    flush $s3
    return [S3::nextdo send_body $thunk writable]
}

# Internal. Send the body to Amazon.
proc S3::send_body {thunk} {
    global errorCode
    set s3 [dict get $thunk S3chan]
    if {[dict exists $thunk orig inbody]} {
	# Send a string. Let's guess that even in non-blocking
	# mode, this is small enough or Tcl's smart enough that
	# we don't blow up the buffer.
	puts -nonewline $s3 [dict get $thunk orig inbody]
	flush $s3
	return [S3::nextdo read_headers $thunk readable]
    } elseif {![dict exists $thunk orig infile]} {
	# No body, no file, so nothing more to do.
	return [S3::nextdo read_headers $thunk readable]
    } elseif {[dict get $thunk blocking]} {
	# A blocking file copy. Still not too hard.
	if {[catch {set inchan [open [dict get $thunk infile] r]} caught]} {
	    S3::fail $thunk "S3 could not open infile - $caught" "" \
		[list S3 local [dict get $thunk infile] $errorCode]
	}
	fconfigure $inchan -translation binary -encoding binary
	fileevent $s3 readable {}
	fileevent $s3 writable {}
	if {[catch {fcopy $inchan $s3 ; flush $s3 ; close $inchan} caught]} {
	    S3::fail $thunk "S3 could not copy infile - $caught" "" \
		[list S3 local [dict get $thunk infile] $errorCode]
	}
	S3::nextdo read_headers $thunk readable
    } else {
	# The hard one. Background file copy.
	fileevent $s3 readable {}
	fileevent $s3 writable {}
	if {[catch {set inchan [open [dict get $thunk infile] r]} caught]} {
	    S3::fail $thunk "S3 could not open infile - $caught" "" \
		[list S3 local [dict get $thunk infile] $errorCode]
	}
	fconfigure $inchan -buffering none -translation binary -encoding binary
	fconfigure $s3 -buffering none -translation binary \
	    -encoding binary -blocking 0 ; # Doesn't work without this?
	dict set thunk inchan $inchan ; # So we can close it.
        fcopy $inchan $s3 -command \
	    [list S3::nextdo read_headers $thunk readable]
    }
}

# Internal. The first line has come back. Grab out the
# stuff we care about.
proc S3::parse_status {thunk line} {
    # Got the status line
    S3::debug "<< $line"
    dict set thunk httpstatusline [string trim $line]
    dict set thunk outheaders [dict create]
    regexp {^HTTP/1.. (...) (.*)$} $line junk code message
    dict set thunk httpstatus $code
    dict set thunk httpmessage [string trim $message]
    return $thunk
}

# A line of header information has come back. Grab it.
# This probably is unhappy with multiple lines for one
# header.
proc S3::parse_header {thunk line} {
    # Got a header line. For now, assume no continuations.
    S3::debug "<< $line"
    set line [string trim $line]
    set left [string range $line 0 [expr {[string first ":" $line]-1}]]
    set right [string range $line [expr {[string first ":" $line]+1}] end]
    set left [string trim [string tolower $left]]
    set right [string trim $right]
    dict set thunk outheaders $left $right
    return $thunk
}

# I don't know if HTTP requires a blank line after the headers if
# there's no body.

# Internal. Read all the headers, and throw if we get EOF before
# we get any headers at all.
proc S3::read_headers {thunk} {
    set s3 [dict get $thunk S3chan]
    flush $s3
    fconfigure $s3 -blocking [dict get $thunk blocking]
    if {[dict get $thunk blocking]} {
	# Blocking. Just read to a blank line. Otherwise,
	# if we use nextdo here, we wind up nesting horribly.
	# If we're not blocking, of course, we're returning
	# to the event loop each time, so that's OK.
	set count [gets $s3 line]
	if {[eof $s3]} {
	    S3::fail $thunk "S3 EOF during status line read" "" "S3 socket EOF"
	}
	set thunk [S3::parse_status $thunk $line]
	while {[string trim $line] != ""} {
	    set count [gets $s3 line]
	    if {$count == -1 && 0 == [dict size [dict get $thunk outheaders]]} {
		S3::fail $thunk "S3 EOF during headers read" "" "S3 socket EOF"
	    }
	    if {[string trim $line] != ""} {
		set thunk [S3::parse_header $thunk $line]
	    }
	}
	return [S3::nextdo read_body $thunk readable]
    } else {
	# Non-blocking, so we have to reenter for each line.
	#  First, fix up the file handle, tho.
	if {[dict exists $thunk inchan]} {
	    close [dict get $thunk inchan]
	    dict unset thunk inchan
	}
	# Now get one header.
	set count [gets $s3 line]
	if {[eof $s3]} {
	    fileevent $s3 readable {}
	    fileevent $s3 writable {}
	    if {![dict exists $thunk httpstatusline]} {
		S3::fail $thunk "S3 EOF during status line read" "" "S3 socket EOF"
	    } elseif {0 == [dict size [dict get $thunk outheaders]]} {
		S3::fail $thunk "S3 EOF during header read" "" "S3 socket EOF"
	    }
	}
	if {$count < 0} return ; # Wait for a whole line
	set line [string trim $line]
	if {![dict exists $thunk httpstatus]} {
	    set thunk [S3::parse_status $thunk $line]
	    S3::nextdo read_headers $thunk readable ; # New thunk here.
	} elseif {$line != ""} {
	    set thunk [S3::parse_header $thunk $line]
	    S3::nextdo read_headers $thunk readable ; # New thunk here.
	} else {
	    # Got an empty line. Switch to copying the body.
	    S3::nextdo read_body $thunk readable
	}
    }
}

# Internal. Read the body of the response.
proc S3::read_body {thunk} {
    set s3 [dict get $thunk S3chan]
    if {[dict get $thunk blocking]} {
	# Easy. Just read it.
	if {[dict exists $thunk orig outchan]} {
	    fcopy $s3 [dict get $thunk orig outchan]
	} else {
	    set x [read $s3]
	    dict set thunk outbody $x
	    #S3::debug "Body: $x" -- Disable unconditional wasteful conversion to string
	    #Need better debug system which does this only when active.
	}
	return [S3::nextdo all_done $thunk readable]
    } else {
	# Nonblocking mode.
	if {[dict exists $thunk orig outchan]} {
	    fileevent $s3 readable {}
	    fileevent $s3 writable {}
	    fcopy $s3 [dict get $thunk orig outchan] -command \
	        [list S3::nextdo all_done $thunk readable]
        } else {
            dict append thunk outbody [read $s3]
	    if {[eof $s3]} {
		# We're done.
		S3::nextdo all_done $thunk readable
	    } else {
		S3::nextdo read_body $thunk readable
	    }
	}
    }
}

# Internal. Convenience function.
proc S3::fail {thunk error errorInfo errorCode} {
    S3::all_done $thunk $error $errorInfo $errorCode
}

# Internal. We're all done the transaction. Clean up everything,
# potentially record errors, close channels, etc etc etc.
proc S3::all_done {thunk {error ""} {errorInfo ""} {errorCode ""}} {
    set s3 [dict get $thunk S3chan]
    catch {
	fileevent $s3 readable {}
	fileevent $s3 writable {}
    }
    if {![dict exists $thunk orig S3chan]} {
	catch {close $s3}
    }
    set res [dict get $thunk orig]
    catch {
	dict set res httpstatus [dict get $thunk httpstatus]
	dict set res httpmessage [dict get $thunk httpmessage]
	dict set res outheaders [dict get $thunk outheaders]
    }
    if {![dict exists $thunk orig outchan]} {
	if {[dict exists $thunk outbody]} {
	    dict set res outbody [dict get $thunk outbody]
	} else {
	    # Probably HTTP failure
	    dict set rest outbody {}
	}
    }
    if {$error ne ""} {
	dict set res error $error
	dict set res errorInfo $errorInfo
	dict set res errorCode $errorCode
    }
    if {![dict get $thunk blocking]} {
	after 0 [list uplevel #0 \
	    [list set [dict get $thunk orig resultvar] $res]]
    }
    if {$error eq "" || ![dict get $thunk blocking] || \
	([dict exists $thunk orig throwsocket] && \
	    "return" == [dict get $thunk orig throwsocket])} {
	return $res
    } else {
	error $error $errorInfo $errorCode
    }
}

# Internal. Parse the lst and make sure it has only keys from the 'valid' list.
# Used to parse arguments going into the higher-level functions.
proc S3::parseargs1 {lst valid} {
    if {[llength $lst] % 2 != 0} {
	error "Option list must be even -name val pairs" \
	    "" [list S3 usage [lindex $lst end] $lst]
    }
    foreach {key val} $lst {
	# Sadly, lsearch applies -glob to the wrong thing for our needs
	set found 0
	foreach v $valid {
	    if {[string match $v $key]} {set found 1 ; break}
	}
	if {!$found} {
	    error "Option list has invalid -key" \
		"" [list S3 usage $key $lst]
	}
    }
    return $lst ; # It seems OK
}

# Internal. Create a variable for higher-level functions to vwait.
proc S3::bgvar {} {
    variable bgvar_counter
    incr bgvar_counter
    set name ::S3::bgvar$bgvar_counter
    return $name
}

# Internal. Given a request and the arguments, run the S3::REST in
# the foreground or the background as appropriate. Also, do retries
# for internal errors.
proc S3::maybebackground {req myargs} {
    variable config
    global errorCode errorInfo
    set mytries [expr {1+[dict get $config -retries]}]
    set delay 2000
    dict set req throwsocket return
    while {1} {
	if {![dict exists $myargs -blocking] || [dict get $myargs -blocking]} {
	    set dict [S3::REST $req]
	} else {
	    set res [bgvar]
	    dict set req resultvar $res
	    S3::REST $req
	    vwait $res
	    set dict [set $res]
	    unset $res ; # clean up temps
	}
	if {[dict exists $dict error]} {
	    set code [dict get $dict errorCode]
	    if {"S3" != [lindex $code 0] || "socket" != [lindex $code 1]} {
		error [dict get $dict error] \
		    [dict get $dict errorInfo] \
		    [dict get $dict errorCode]
	    }
	}
	incr mytries -1
	incr delay $delay ; if {20000 < $delay} {set delay 20000}
	if {"500" ne [dict get $dict httpstatus] || $mytries <= 0} {
	    return $dict
	}
	if {![dict exists $myargs -blocking] || [dict get $myargs -blocking]} {
	    after $delay
	} else {
	    set timer [bgvar]
	    after $delay [list set $timer 1]
	    vwait $timer
	    unset $timer
	}
    }
}

# Internal. Maybe throw an HTTP error if httpstatus not in 200 range.
proc S3::throwhttp {dict} {
    set hs [dict get $dict httpstatus]
    if {![string match "2??" $hs]} {
	error "S3 received non-OK HTTP result of $hs"  "" \
	    [list S3 remote $hs $dict]
    }
}

# Public. Returns the list of buckets for this user.
proc S3::ListAllMyBuckets {args} {
    checkinit ; # I know this gets done later.
    set myargs [S3::parseargs1 $args {-blocking -parse-xml -result-type}]
    if {![dict exists $myargs -result-type]} {
	dict set myargs -result-type names
    }
    if {![dict exists $myargs -blocking]} {
	dict set myargs -blocking true
    }
    set restype [dict get $myargs -result-type]
    if {$restype eq "REST" && [dict exists $myargs -parse-xml]} {
	error "Do not use REST with -parse-xml" "" \
	    [list S3 usage -parse-xml $args]
    }
    if {![dict exists $myargs -parse-xml]} {
	# We need to fetch the results.
	set req [dict create verb GET resource /]
	set dict [S3::maybebackground $req $myargs]
	if {$restype eq "REST"} {
	    return $dict ; #we're done!
	}
	S3::throwhttp $dict ; #make sure it worked.
	set xml [dict get $dict outbody]
    } else {
	set xml [dict get $myargs -parse-xml]
    }
    # Here, we either already returned the dict, or the XML is in "xml".
    if {$restype eq "xml"} {return $xml}
    if {[catch {set pxml [::xsxp::parse $xml]}]} {
	error "S3 invalid XML structure" "" [list S3 usage xml $xml]
    }
    if {$restype eq "pxml"} {return $pxml}
    if {$restype eq "dict" || $restype eq "names"} {
	set buckets [::xsxp::fetch $pxml "Buckets" %CHILDREN]
	set names {} ; set dates {}
	foreach bucket $buckets {
	    lappend names [::xsxp::fetch $bucket "Name" %PCDATA]
	    lappend dates [::xsxp::fetch $bucket "CreationDate" %PCDATA]
	}
	if {$restype eq "names"} {
	    return $names
	} else {
	    return [dict create \
		Owner/ID [::xsxp::fetch $pxml "Owner/ID" %PCDATA] \
		Owner/DisplayName \
		    [::xsxp::fetch $pxml "Owner/DisplayName" %PCDATA] \
		Bucket/Name $names Bucket/Date $dates \
	    ]
	}
    }
    if {$restype eq "owner"} {
	return [list [::xsxp::fetch $pxml Owner/ID %PCDATA] \
	    [::xsxp::fetch $pxml Owner/DisplayName %PCDATA] ]
    }
    error "ListAllMyBuckets requires -result-type to be REST, xml, pxml, dict, owner, or names" "" [list S3 usage -result-type $args]
}

# Public. Create a bucket.
proc S3::PutBucket {args} {
    checkinit
    set myargs [S3::parseargs1 $args {-blocking -bucket -acl}]
    if {![dict exists $myargs -acl]} {
	dict set myargs -acl [S3::Configure -default-acl]
    }
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict exists $myargs -bucket]} {
	error "PutBucket requires -bucket" "" [list S3 usage -bucket $args]
    }

    set req [dict create verb PUT resource /[dict get $myargs -bucket]]
    if {[dict exists $myargs -acl]} {
	dict set req headers [list x-amz-acl [dict get $myargs -acl]]
    }
    set dict [S3::maybebackground $req $myargs]
    S3::throwhttp $dict
    return "" ; # until we decide what to return.
}

# Public. Delete a bucket.
proc S3::DeleteBucket {args} {
    checkinit
    set myargs [S3::parseargs1 $args {-blocking -bucket}]
    if {![dict exists $myargs -bucket]} {
	error "DeleteBucket requires -bucket" "" [list S3 usage -bucket $args]
    }
    dict set myargs -bucket [string trim [dict get $args -bucket] "/ "]

    set req [dict create verb DELETE resource /[dict get $myargs -bucket]]
    set dict [S3::maybebackground $req $myargs]
    S3::throwhttp $dict
    return "" ; # until we decide what to return.
}

# Internal. Suck out the one and only answer from the list, if needed.
proc S3::firstif {list myargs} {
    if {[dict exists $myargs -max-keys]} {
	return [lindex $list 0]
    } else {
	return $list
    }
}

# Public. Get the list of resources within a bucket.
proc S3::GetBucket {args} {
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -parse-xml -max-keys
	-result-type -prefix -delimiter
	-TEST
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict get $myargs -bucket]} {
	error "GetBucket requires -bucket" "" [list S3 usage -bucket $args]
    }
    if {[dict get $myargs -bucket] eq ""} {
	error "GetBucket requires -bucket nonempty" "" \
	    [list S3 usage -bucket $args]
    }
    if {![dict exists $myargs -result-type]} {
	dict set myargs -result-type names
    }
    if {[dict get $myargs -result-type] eq "REST" && \
	    [dict exists $myargs "-parse-xml"]} {
	error "GetBucket can't have -parse-xml with REST result" "" \
	    [list S3 usage -parse-xml $args]
    }
    set req [dict create verb GET resource /[dict get $myargs -bucket]]
    set parameters {}
    # Now, just to make test cases easier...
    if {[dict exists $myargs -TEST]} {
	dict set parameters max-keys [dict get $myargs -TEST]
    }
    # Back to your regularly scheduled argument parsing
    if {[dict exists $myargs -max-keys]} {
	dict set parameters max-keys [dict get $myargs -max-keys]
    }
    if {[dict exists $myargs -prefix]} {
	set p [dict get $myargs -prefix]
	if {[string match "/*" $p]} {
	    set p [string range $p 1 end]
	}
	dict set parameters prefix $p
    }
    if {[dict exists $myargs -delimiter]} {
	dict set parameters delimiter [dict get $myargs -delimiter]
    }
    set nextmarker0 {} ; # We use this for -result-type dict.
    if {![dict exists $myargs -parse-xml]} {
	# Go fetch answers.
	#   Current xaction in "0" vars, with accumulation in "L" vars.
	#   Ultimate result of this loop is $RESTL, a list of REST results.
	set RESTL [list]
	while {1} {
	    set req0 $req ; dict set req0 parameters $parameters
	    set REST0 [S3::maybebackground $req0 $myargs]
	    S3::throwhttp $REST0
	    lappend RESTL $REST0
	    if {[dict exists $myargs -max-keys]} {
		# We were given a limit, so just return the answer.
		break
	    }
	    set pxml0 [::xsxp::parse [dict get $REST0 outbody]]
	    set trunc0 [expr "true" eq \
		[::xsxp::fetch $pxml0 IsTruncated %PCDATA]]
	    if {!$trunc0} {
		# We've retrieved the final block, so go parse it.
		set nextmarker0 "" ; # For later.
		break
	    }
	    # Find the highest contents entry. (Would have been
	    # easier if Amazon always supplied NextMarker.)
	    set nextmarker0 {}
	    foreach {only tag} {Contents Key CommonPrefixes Prefix} {
		set only0 [::xsxp::only $pxml0 $only]
		if {0 < [llength $only0]} {
		    set k0 [::xsxp::fetch [lindex $only0 end] $tag %PCDATA]
		    if {[string compare $nextmarker0 $k0] < 0} {
			set nextmarker0 $k0
		    }
		}
	    }
	    if {$nextmarker0 eq ""} {error "Internal Error in S3 library"}
	    # Here we have the next marker, so fetch the next REST
	    dict set parameters marker $nextmarker0
	    # Note - $nextmarker0 is used way down below again!
	}
	# OK, at this point, the caller did not provide the xml via -parse-xml
	# And now we have a list of REST results. So let's process.
	if {[dict get $myargs -result-type] eq "REST"} {
	    return [S3::firstif $RESTL $myargs]
	}
	set xmlL [list]
	foreach entry $RESTL {
	    lappend xmlL [dict get $entry outbody]
	}
	unset RESTL ; # just to save memory
    } else {
	# Well, we've parsed out the XML from the REST,
	# so we're ready for -parse-xml
	set xmlL [list [dict get $myargs -parse-xml]]
    }
    if {[dict get $myargs -result-type] eq "xml"} {
	return [S3::firstif $xmlL $myargs]
    }
    set pxmlL [list]
    foreach xml $xmlL {
	lappend pxmlL [::xsxp::parse $xml]
    }
    unset xmlL
    if {[dict get $myargs -result-type] eq "pxml"} {
	return [S3::firstif $pxmlL $myargs]
    }
    # Here, for result types of "names" and "dict",
    # we need to actually parse out all the results.
    if {[dict get $myargs -result-type] eq "names"} {
	# The easy one.
	set names [list]
	foreach pxml $pxmlL {
	    set con0 [::xsxp::only $pxml Contents]
	    set con1 [::xsxp::only $pxml CommonPrefixes]
	    lappend names {*}[concat [::xsxp::fetchall $con0 Key %PCDATA] \
		[::xsxp::fetchall $con1 Prefix %PCDATA]]
	}
	return [lsort $names]
    } elseif {[dict get $myargs -result-type] eq "dict"} {
	# The harder one.
	set last0 [lindex $pxmlL end]
	set res [dict create]
	foreach thing {Name Prefix Marker MaxKeys IsTruncated} {
	    dict set res $thing [::xsxp::fetch $last0 $thing %PCDATA?]
	}
	dict set res NextMarker $nextmarker0 ; # From way up above.
	set Prefix [list]
	set names {Key LastModified ETag Size Owner/ID Owner/DisplayName StorageClass}
	foreach name $names {set $name [list]}
	foreach pxml $pxmlL {
	    foreach tag [::xsxp::only $pxml CommonPrefixes] {
		lappend Prefix [::xsxp::fetch $tag Prefix %PCDATA]
	    }
	    foreach tag [::xsxp::only $pxml Contents] {
		foreach name $names {
		    lappend $name [::xsxp::fetch $tag $name %PCDATA]
		}
	    }
	}
	dict set res CommonPrefixes/Prefix $Prefix
	foreach name $names {dict set res $name [set $name]}
	return $res
    } else {
	# The hardest one ;-)
	error "GetBucket Invalid result type, must be REST, xml, pxml, names, or dict" "" [list S3 usage -result-type $args]
    }
}

# Internal. Compare a resource to a file.
# Returns 1 if they're different, 0 if they're the same.
#   Note that using If-Modified-Since and/or If-Match,If-None-Match
#   might wind up being more efficient than pulling the head
#   and checking. However, this allows for slop, checking both
#   the etag and the date, only generating local etag if the
#   date and length indicate they're the same, and so on.
# Direction is G or P for Get or Put.
# Assumes the source always exists. Obviously, Get and Put will throw if not,
# but not because of this.
proc S3::compare {myargs direction} {
    variable config
    global errorInfo
    set compare [dict get $myargs -compare]
    if {$compare ni {always never exists missing newer date checksum different}} {
	error "-compare must be always, never, exists, missing, newer, date, checksum, or different" "" \
	    [list S3 usage -compare $myargs]
    }
    if {"never" eq $compare} {return 0}
    if {"always" eq $compare} {return 1}
    if {[dict exists $myargs -file] && [file exists [dict get $myargs -file]]} {
	set local_exists 1
    } else {
	set local_exists 0
    }
    # Avoid hitting S3 if we don't need to.
    if {$direction eq "G" && "exists" eq $compare} {return $local_exists}
    if {$direction eq "G" && "missing" eq $compare} {
	return [expr !$local_exists]
    }
    # We need to get the headers from the resource.
    set req [dict create \
	resource /[dict get $myargs -bucket]/[dict get $myargs -resource] \
	verb HEAD ]
    set res [S3::maybebackground $req $myargs]
    set httpstatus [dict get $res httpstatus]
    if {"404" eq $httpstatus} {
	set remote_exists 0
    } elseif {[string match "2??" $httpstatus]} {
	set remote_exists 1
    } else {
	error "S3: Neither 404 or 2xx on conditional compare" "" \
	    [list S3 remote $httpstatus $res]
    }
    if {$direction eq "P"} {
	if {"exists" eq $compare} {return $remote_exists}
	if {"missing" eq $compare} {return [expr {!$remote_exists}]}
	if {!$remote_exists} {return 1}
    } elseif {$direction eq "G"} {
	# Actually already handled above, but it never hurts...
	if {"exists" eq $compare} {return $local_exists}
	if {"missing" eq $compare} {return [expr {!$local_exists}]}
    }
    set outheaders [dict get $res outheaders]
    if {[dict exists $outheaders content-length]} {
	set remote_length [dict get $outheaders content-length]
    } else {
	set remote_length -1
    }
    if {[dict exists $outheaders etag]} {
	set remote_etag [string tolower \
	    [string trim [dict get $outheaders etag] \"]]
    } else {
	set remote_etag "YYY"
    }
    if {[dict exists $outheaders last-modified]} {
	set remote_date [clock scan [dict get $outheaders last-modified]]
    } else {
	set remote_date -1
    }
    if {[dict exists $myargs -content]} {
	# Probably should work this out better...
	#set local_length [string length [encoding convert-to utf-8 \
	    #[dict get $myargs -content]]]
	set local_length [string length [dict get $myargs -content]]
    } elseif {$local_exists} {
	if {[catch {file size [dict get $myargs -file]} local_length]} {
	    error "S3: Couldn't stat [dict get $myargs -file]" "" \
		[list S3 local $errorInfo]
	}
    } else {
	set local_length -2
    }
    if {[dict exists $myargs -content]} {
	set local_date [clock seconds]
    } elseif {$local_exists} {
	set local_date [file mtime [dict get $myargs -file]]
	# Shouldn't throw, since [file size] worked.
    } else {
	set local_date -2
    }
    if {$direction eq "P"} {
	if {"newer" eq $compare} {
	    if {$remote_date < $local_date - [dict get $config -slop-seconds]} {
		return 1 ; # Yes, local is newer
	    } else {
		return 0 ; # Older, or the same
	    }
	}
    } elseif {$direction eq "G"} {
	if {"newer" eq $compare} {
	    if {$local_date < $remote_date - [dict get $config -slop-seconds]} {
		return 1 ; # Yes, remote is later.
	    } else {
		return 0 ; # Local is older or same.
	    }
	}
    }
    if {[dict get $config -slop-seconds] <= abs($local_date - $remote_date)} {
	set date_diff 1 ; # Difference is greater
    } else {
	set date_diff 0 ; # Difference negligible
    }
    if {"date" eq $compare} {return $date_diff}
    if {"different" eq $compare && [dict exists $myargs -file] && $date_diff} {
	return 1
    }
    # Date's the same, but we're also interested in content, so check the rest
    # Only others to handle are checksum and different-with-matching-dates
    if {$local_length != $remote_length} {return 1} ; #easy quick case
    if {[dict exists $myargs -file] && $local_exists} {
	if {[catch {
	    # Maybe deal with making this backgroundable too?
	    set local_etag [string tolower \
		[::md5::md5 -hex -filename [dict get $myargs -file]]]
	} caught]} {
	    # Maybe you can stat but not read it?
	    error "S3 could not hash file" "" \
		[list S3 local [dict get $myargs -file] $errorInfo]
	}
    } elseif {[dict exists $myargs -content]} {
	set local_etag [string tolower \
	    [string tolower [::md5::md5 -hex [dict get $myargs -content]]]]
    } else {
	set local_etag "XXX"
    }
    # puts "local:  $local_etag\nremote: $remote_etag"
    if {$local_etag eq $remote_etag} {return 0} {return 1}
}

# Internal. Calculates the ACL based on file permissions.
proc S3::calcacl {myargs} {
    # How would one work this under Windows, then?
    # Silly way: invoke [exec cacls $filename],
    # parse the result looking for Everyone:F or Everyone:R
    # Messy security if someone replaces the cacls.exe or something.
    error "S3 Not Yet Implemented" "" [list S3 notyet calcacl $myargs]
    set result [S3::Configure -default-acl]
    catch {
	set chmod [file attributes [dict get $myargs -file] -permissions]
	set chmod [expr {$chmod & 6}]
	if {$chmod == 0} {set result private}
	if {$chmod == 2} {set result public-write}
	if {$chmod == 6} {set result public-read-write}
    }
}

# Public. Put a resource into a bucket.
proc S3::Put {args} {
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -file -content -resource -acl
	-content-type -x-amz-meta-* -compare
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict get $myargs -bucket]} {
	error "Put requires -bucket" "" [list S3 usage -bucket $args]
    }
    if {![dict exists $myargs -blocking]} {
	dict set myargs -blocking true
    }
    if {![dict exists $myargs -file] && ![dict exists $myargs -content]} {
	error "Put requires -file or -content" "" [list S3 usage -file $args]
    }
    if {[dict exists $myargs -file] && [dict exists $myargs -content]} {
	error "Put says -file, -content mutually exclusive" "" [list S3 usage -file $args]
    }
    if {![dict exists $myargs -resource]} {
	error "Put requires -resource" "" [list S3 usage -resource $args]
    }
    if {![dict exists $myargs -compare]} {
	dict set myargs -compare [S3::Configure -default-compare]
    }
    if {![dict exists $myargs -acl] && "" ne [S3::Configure -default-acl]} {
	dict set myargs -acl [S3::Configure -default-acl]
    }
    if {[dict exists $myargs -file] && \
	    "never" ne [dict get $myargs -compare] && \
	    ![file exists [dict get $myargs -file]]} {
	error "Put -file doesn't exist: [dict get $myargs -file]" \
	    "" [list S3 usage -file $args]
    }
    # Clean up bucket, and take one leading slash (if any) off resource.
    if {[string match "/*" [dict get $myargs -resource]]} {
	dict set myargs -resource \
	    [string range [dict get $myargs -resource] 1 end]
    }
    # See if we need to copy it.
    set comp [S3::compare $myargs P]
    if {!$comp} {return 0} ;  # skip it, then.

    # Oookeydookey. At this point, we're actually going to send
    # the file, so all we need to do is build the request array.
    set req [dict create verb PUT \
	resource /[dict get $myargs -bucket]/[dict get $myargs -resource]]
    if {[dict exists $myargs -file]} {
	dict set req infile [dict get $myargs -file]
    } else {
	dict set req inbody [dict get $myargs -content]
    }
    if {[dict exists $myargs -content-type]} {
	dict set req content-type [dict get $myargs -content-type]
    }
    set headers {}
    foreach xhead [dict keys $myargs -x-amz-meta-*] {
	dict set headers [string range $xhead 1 end] [dict get $myargs $xhead]
    }
    set xmlacl "" ; # For calc and keep
    if {[dict exists $myargs -acl]} {
	if {[dict get $myargs -acl] eq "calc"} {
	    # We could make this more complicated by
	    # assigning it to xmlacl after building it.
	    dict set myargs -acl [S3::calcacl $myargs]
	} elseif {[dict get $myargs -acl] eq "keep"} {
	    dict set myargs -acl [S3::Configure -default-acl]
	    catch {
		set xmlacl [S3::GetAcl \
		    -bucket [dict get $myargs -bucket] \
		    -resource [dict get $myargs -resource] \
		    -blocking [dict get $myargs -blocking] \
		    -result-type xml]
	    }
	}
	dict set headers x-amz-acl [dict get $myargs -acl]
    }
    dict set req headers $headers
    # That should do it.
    set res [S3::maybebackground $req $myargs]
    S3::throwhttp $res
    if {"<" == [string index $xmlacl 0]} {
	# Set the saved ACL back on the new object
	S3::PutAcl \
	    -bucket [dict get $myargs -bucket] \
	    -resource [dict get $myargs -resource] \
	    -blocking [dict get $myargs -blocking] \
	    -acl $xmlacl
    }
    return 1 ; # Yep, we copied it!
}

# Public. Get a resource from a bucket.
proc S3::Get {args} {
    global errorCode
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -file -content -resource -timestamp
	-headers -compare
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict get $myargs -bucket]} {
	error "Get requires -bucket" "" [list S3 usage -bucket $args]
    }
    if {![dict exists $myargs -file] && ![dict exists $myargs -content]} {
	error "Get requires -file or -content" "" [list S3 usage -file $args]
    }
    if {[dict exists $myargs -file] && [dict exists $myargs -content]} {
	error "Get says -file, -content mutually exclusive" "" [list S3 usage -file $args]
    }
    if {![dict exists $myargs -resource]} {
	error "Get requires -resource" "" [list S3 usage -resource $args]
    }
    if {![dict exists $myargs -compare]} {
	dict set myargs -compare [S3::Configure -default-compare]
    }
    # Clean up bucket, and take one leading slash (if any) off resource.
    if {[string match "/*" [dict get $myargs -resource]]} {
	dict set myargs -resource \
	    [string range [dict get $myargs -resource] 1 end]
    }
    # See if we need to copy it.
    if {"never" eq [dict get $myargs -compare]} {return 0}
    if {[dict exists $myargs -content]} {
	set comp 1
    } else {
	set comp [S3::compare $myargs G]
    }
    if {!$comp} {return 0} ;  # skip it, then.

    # Oookeydookey. At this point, we're actually going to fetch
    # the file, so all we need to do is build the request array.
    set req [dict create verb GET \
	resource /[dict get $myargs -bucket]/[dict get $myargs -resource]]
    if {[dict exists $myargs -file]} {
	set pre_exists [file exists [dict get $myargs -file]]
	if {[catch {
	    set x [open [dict get $myargs -file] w]
	    fconfigure $x -translation binary -encoding binary
	} caught]} {
	    error "Get could not create file [dict get $myargs -file]" "" \
		[list S3 local -file $errorCode]
	}
	dict set req outchan $x
    }
    # That should do it.
    set res [S3::maybebackground $req $myargs]
    if {[dict exists $req outchan]} {
	catch {close [dict get $req outchan]}
	if {![string match "2??" [dict get $res httpstatus]] && !$pre_exists} {
	    catch {file delete -force -- [dict get $myargs -file]}
	}
    }
    S3::throwhttp $res
    if {[dict exists $myargs -headers]} {
	uplevel 1 \
	    [list set [dict get $myargs -headers] [dict get $res outheaders]]
    }
    if {[dict exists $myargs -content]} {
	uplevel 1 \
	    [list set [dict get $myargs -content] [dict get $res outbody]]
    }
    if {[dict exists $myargs -timestamp] && [dict exists $myargs -file]} {
	if {"aws" eq [dict get $myargs -timestamp]} {
	    catch {
		set t [dict get $res outheaders last-modified]
		set t [clock scan $t -gmt true]
		file mtime [dict get $myargs -file] $t
	    }
	}
    }
    return 1 ; # Yep, we copied it!
}

# Public. Get information about a resource in a bucket.
proc S3::Head {args} {
    global errorCode
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -resource -headers -dict -status
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict get $myargs -bucket]} {
	error "Head requires -bucket" "" [list S3 usage -bucket $args]
    }
    if {![dict exists $myargs -resource]} {
	error "Head requires -resource" "" [list S3 usage -resource $args]
    }
    # Clean up bucket, and take one leading slash (if any) off resource.
    if {[string match "/*" [dict get $myargs -resource]]} {
	dict set myargs -resource \
	    [string range [dict get $myargs -resource] 1 end]
    }
    set req [dict create verb HEAD \
	resource /[dict get $myargs -bucket]/[dict get $myargs -resource]]
    set res [S3::maybebackground $req $myargs]
    if {[dict exists $myargs -dict]} {
	uplevel 1 \
	    [list set [dict get $myargs -dict] $res]
    }
    if {[dict exists $myargs -headers]} {
	uplevel 1 \
	    [list set [dict get $myargs -headers] [dict get $res outheaders]]
    }
    if {[dict exists $myargs -status]} {
	set x [list [dict get $res httpstatus] [dict get $res httpmessage]]
	uplevel 1 \
	    [list set [dict get $myargs -status] $x]
    }
    return [string match "2??" [dict get $res httpstatus]]
}

# Public. Get the full ACL from an object and parse it into something useful.
proc S3::GetAcl {args} {
    global errorCode
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -resource -result-type -parse-xml
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {![dict exists $myargs -result-type]} {
	dict set myargs -result-type "dict"
    }
    set restype [dict get $myargs -result-type]
    if {$restype eq "REST" && [dict exists $myargs -parse-xml]} {
	error "Do not use REST with -parse-xml" "" \
	    [list S3 usage -parse-xml $args]
    }
    if {![dict exists $myargs -parse-xml]} {
	# We need to fetch the results.
	if {"" eq [dict get $myargs -bucket]} {
	    error "GetAcl requires -bucket" "" [list S3 usage -bucket $args]
	}
	if {![dict exists $myargs -resource]} {
	    error "GetAcl requires -resource" "" [list S3 usage -resource $args]
	}
	# Clean up bucket, and take one leading slash (if any) off resource.
	if {[string match "/*" [dict get $myargs -resource]]} {
	    dict set myargs -resource \
		[string range [dict get $myargs -resource] 1 end]
	}
	set req [dict create verb GET \
	    resource /[dict get $myargs -bucket]/[dict get $myargs -resource] \
	    rtype acl]
	set dict [S3::maybebackground $req $myargs]
	if {$restype eq "REST"} {
	    return $dict ; #we're done!
	}
	S3::throwhttp $dict ; #make sure it worked.
	set xml [dict get $dict outbody]
    } else {
	set xml [dict get $myargs -parse-xml]
    }
    if {[dict get $myargs -result-type] == "xml"} {
	return $xml
    }
    set pxml [xsxp::parse $xml]
    if {[dict get $myargs -result-type] == "pxml"} {
	return $pxml
    }
    if {[dict get $myargs -result-type] == "dict"} {
	array set resdict {}
	set owner [xsxp::fetch $pxml Owner/ID %PCDATA]
	set grants [xsxp::fetch $pxml AccessControlList %CHILDREN]
	foreach grant $grants {
	    set perm [xsxp::fetch $grant Permission %PCDATA]
	    set id ""
	    catch {set id [xsxp::fetch $grant Grantee/ID %PCDATA]}
	    if {$id == ""} {
		set id [xsxp::fetch $grant Grantee/URI %PCDATA]
	    }
	    lappend resdict($perm) $id
	}
	return [dict create owner $owner acl [array get resdict]]
    }
    error "GetAcl requires -result-type to be REST, xml, pxml or dict" "" [list S3 usage -result-type $args]
}

# Make one Grant thingie
proc S3::engrant {who what} {
    if {$who == "AuthenticatedUsers" || $who == "AllUsers"} {
	set who http://acs.amazonaws.com/groups/global/$who
    }
    if {-1 != [string first "//" $who]} {
	set type Group ; set tag URI
    } elseif {-1 != [string first "@" $who]} {
	set type AmazonCustomerByEmail ; set tag EmailAddress
    } else {
	set type CanonicalUser ; set tag ID
    }
    set who [string map {< &lt; > &gt; & &amp;} $who]
    set what [string toupper $what]
    set xml "<Grant><Grantee xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:type=\"$type\"><$tag>$who</$tag></Grantee>"
    append xml "<Permission>$what</Permission></Grant>"
    return $xml
}

# Make the owner header
proc S3::enowner {owner} {
    return "<AccessControlPolicy xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\"><Owner><ID>$owner</ID></Owner><AccessControlList>"
    return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<AccessControlPolicy xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\"><Owner><ID>$owner</ID></Owner><AccessControlList>"
}

proc S3::endacl {} {
    return "</AccessControlList></AccessControlPolicy>\n"
}

# Public. Set the ACL on an existing object.
proc S3::PutAcl {args} {
    global errorCode
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -resource -acl -owner
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict get $myargs -bucket]} {
	error "PutAcl requires -bucket" "" [list S3 usage -bucket $args]
    }
    if {![dict exists $myargs -resource]} {
	error "PutAcl requires -resource" "" [list S3 usage -resource $args]
    }
    if {![dict exists $myargs -acl]} {
	dict set myargs -acl [S3::Configure -default-acl]
    }
    dict set myargs -acl [string trim [dict get $myargs -acl]]
    if {[dict get $myargs -acl] == ""} {
	dict set myargs -acl [S3::Configure -default-acl]
    }
    if {[dict get $myargs -acl] == ""} {
	error "PutAcl requires -acl" "" [list D3 usage -resource $args]
    }
    # Clean up bucket, and take one leading slash (if any) off resource.
    if {[string match "/*" [dict get $myargs -resource]]} {
	dict set myargs -resource \
	    [string range [dict get $myargs -resource] 1 end]
    }
    # Now, figure out the XML to send.
    set acl [dict get $myargs -acl]
    set owner ""
    if {"<" != [string index $acl 0] && ![dict exists $myargs -owner]} {
	# Grab the owner off the resource
	set req [dict create verb GET \
	    resource /[dict get $myargs -bucket]/[dict get $myargs -resource] \
	    rtype acl]
	set dict [S3::maybebackground $req $myargs]
	S3::throwhttp $dict ; #make sure it worked.
	set xml [dict get $dict outbody]
	set pxml [xsxp::parse $xml]
	set owner [xsxp::fetch $pxml Owner/ID %PCDATA]
    }
    if {[dict exists $myargs -owner]} {
	set owner [dict get $myargs -owner]
    }
    set xml [enowner $owner]
    if {"" == $acl || "private" == $acl} {
	append xml [engrant $owner FULL_CONTROL]
	append xml [endacl]
    } elseif {"public-read" == $acl} {
	append xml [engrant $owner FULL_CONTROL]
	append xml [engrant AllUsers READ]
	append xml [endacl]
    } elseif {"public-read-write" == $acl} {
	append xml [engrant $owner FULL_CONTROL]
	append xml [engrant AllUsers READ]
	append xml [engrant AllUsers WRITE]
	append xml [endacl]
    } elseif {"authenticated-read" == $acl} {
	append xml [engrant $owner FULL_CONTROL]
	append xml [engrant AuthenticatedUsers READ]
	append xml [endacl]
    } elseif {"<" == [string index $acl 0]} {
	set xml $acl
    } elseif {[llength $acl] % 2 != 0} {
	error "S3::PutAcl -acl must be xml, private, public-read, public-read-write, authenticated-read, or a dictionary" \
	"" [list S3 usage -acl $acl]
    } else {
	# ACL in permission/ID-list format.
	if {[dict exists $acl owner] && [dict exists $acl acl]} {
	    set xml [S3::enowner [dict get $acl owner]]
	    set acl [dict get $acl acl]
	}
	foreach perm {FULL_CONTROL READ READ_ACP WRITE WRITE_ACP} {
	    if {[dict exists $acl $perm]} {
		foreach id [dict get $acl $perm] {
		    append xml [engrant $id $perm]
		}
	    }
	}
	append xml [endacl]
    }
    set req [dict create verb PUT \
	resource /[dict get $myargs -bucket]/[dict get $myargs -resource] \
	inbody $xml \
	rtype acl]
    set res [S3::maybebackground $req $myargs]
    S3::throwhttp $res ; #make sure it worked.
    return $xml
}

# Public. Delete a resource from a bucket.
proc S3::Delete {args} {
    global errorCode
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -resource -status
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict get $myargs -bucket]} {
	error "Delete requires -bucket" "" [list S3 usage -bucket $args]
    }
    if {![dict exists $myargs -resource]} {
	error "Delete requires -resource" "" [list S3 usage -resource $args]
    }
    # Clean up bucket, and take one leading slash (if any) off resource.
    if {[string match "/*" [dict get $myargs -resource]]} {
	dict set myargs -resource \
	    [string range [dict get $myargs -resource] 1 end]
    }
    set req [dict create verb DELETE \
	resource /[dict get $myargs -bucket]/[dict get $myargs -resource]]
    set res [S3::maybebackground $req $myargs]
    if {[dict exists $myargs -status]} {
	set x [list [dict get $res httpstatus] [dict get $res httpmessage]]
	uplevel 1 \
	    [list set [dict get $myargs -status] $x]
    }
    return [string match "2??" [dict get $res httpstatus]]
}

# Some helper routines for Push, Pull, and Sync

# Internal. Filter for fileutil::find.
proc S3::findfilter {dirs name} {
    # In particular, skip links, devices, etc.
    if {$dirs} {
	return [expr {[file isdirectory $name] || [file isfile $name]}]
    } else {
	return [file isfile $name]
    }
}

# Internal.  Get list of local files, appropriately trimmed.
proc S3::getLocal {root dirs} {
    # Thanks to Michael Cleverly for this first line...
    set base [file normalize [file join [pwd] $root]]
    if {![string match "*/" $base]} {
	set base $base/
    }
    set files {} ; set bl [string length $base]
    foreach file [fileutil::find $base [list S3::findfilter $dirs]] {
	if {[file isdirectory $file]} {
	    lappend files [string range $file $bl end]/
	} else {
	    lappend files [string range $file $bl end]
	}
    }
    set files [lsort $files]
    # At this point, $files is a sorted list of all the local files,
    # with a trailing / on any directories included in the list.
    return $files
}

# Internal. Get list of remote resources, appropriately trimmed.
proc S3::getRemote {bucket prefix blocking} {
    set prefix [string trim $prefix " /"]
    if {0 != [string length $prefix]} {append prefix /}
    set res [S3::GetBucket -bucket $bucket -prefix $prefix \
	-result-type names -blocking $blocking]
    set names {} ; set pl [string length $prefix]
    foreach name $res {
	lappend names [string range $name $pl end]
    }
    return [lsort $names]
}

# Internal. Create any directories we need to put the file in place.
proc S3::makeDirs {directory suffix} {
    set sofar {}
    set nodes [split $suffix /]
    set nodes [lrange $nodes 0 end-1]
    foreach node $nodes {
	lappend sofar $node
	set tocheck [file join $directory {*}$sofar]
	if {![file exists $tocheck]} {
	    catch {file mkdir $tocheck}
	}
    }
}

# Internal. Default progress monitor for push, pull, toss.
proc S3::ignore {args} {} ; # default progress monitor

# Internal. For development and testing. Progress monitor.
proc S3::printargs {args} {puts $args} ; # For testing.

# Public. Send a local directory tree to S3.
proc S3::Push {args} {
    uplevel #0 package require fileutil
    global errorCode errorInfo
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -prefix -directory
	-compare -x-amz-meta-* -acl -delete -error -progress
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict get $myargs -bucket]} {
	error "Push requires -bucket" "" [list S3 usage -bucket $args]
    }
    if {![dict exists $myargs -directory]} {
	error "Push requires -directory" "" [list S3 usage -directory $args]
    }
    # Set default values.
    set defaults "
    -acl \"[S3::Configure -default-acl]\"
    -compare [S3::Configure -default-compare]
    -prefix {} -delete 0 -error continue -progress ::S3::ignore -blocking 1"
    foreach {key val} $defaults {
	if {![dict exists $myargs $key]} {dict set myargs $key $val}
    }
    # Pull out arguments for convenience
    foreach i {progress prefix directory bucket blocking} {
	set $i [dict get $myargs -$i]
    }
    set prefix [string trimright $prefix /]
    set meta [dict filter $myargs key x-amz-meta-*]
    # We're readdy to roll here.
    uplevel 1 [list {*}$progress args $myargs]
    if {[catch {
	set local [S3::getLocal $directory 0]
    } caught]}  {
	error "Push could not walk local directory - $caught" \
	    $errorInfo $errorCode
    }
    uplevel 1 [list {*}$progress local $local]
    if {[catch {
	set remote [S3::getRemote $bucket $prefix $blocking]
    } caught]} {
	error "Push could not walk remote directory - $caught" \
	    $errorInfo $errorCode
    }
    uplevel 1 [list {*}$progress remote $remote]
    set result [dict create]
    set result0 [dict create \
	filescopied 0 bytescopied 0 compareskipped 0 \
	errorskipped 0 filesdeleted 0 filesnotdeleted 0]
    foreach suffix $local {
	uplevel 1 [list {*}$progress copy $suffix start]
	set err [catch {
	    S3::Put -bucket $bucket -blocking $blocking \
	    -file [file join $directory $suffix] \
	    -resource $prefix/$suffix \
	    -acl [dict get $myargs -acl] \
	    {*}$meta \
	    -compare [dict get $myargs -compare]} caught]
	if {$err} {
	    uplevel 1 [list {*}$progress copy $suffix $errorCode]
	    dict incr result0 errorskipped
	    dict set result $suffix $errorCode
	    if {[dict get $myargs -error] eq "throw"} {
		error "Push failed to Put - $caught" $errorInfo $errorCode
	    } elseif {[dict get $myargs -error] eq "break"} {
		break
	    }
	} else {
	    if {$caught} {
		uplevel 1 [list {*}$progress copy $suffix copied]
		dict incr result0 filescopied
		dict incr result0 bytescopied \
		    [file size [file join $directory $suffix]]
		dict set result $suffix copied
	    } else {
		uplevel 1 [list {*}$progress copy $suffix skipped]
		dict incr result0 compareskipped
		dict set result $suffix skipped
	    }
	}
    }
    # Now do deletes, if so desired
    if {[dict get $myargs -delete]} {
	foreach suffix $remote {
	    if {$suffix ni $local} {
		set err [catch {
		    S3::Delete -bucket $bucket -blocking $blocking \
			-resource $prefix/$suffix } caught]
		if {$err} {
		    uplevel 1 [list {*}$progress delete $suffix $errorCode]
		    dict incr result0 filesnotdeleted
		    dict set result $suffix notdeleted
		} else {
		    uplevel 1 [list {*}$progress delete $suffix {}]
		    dict incr result0 filesdeleted
		    dict set result $suffix deleted
		}
	    }
	}
    }
    dict set result {} $result0
    uplevel 1 [list {*}$progress finished $result]
    return $result
}

# Public. Fetch a portion of a remote bucket into a local directory tree.
proc S3::Pull {args} {
    # This is waaaay to similar to Push for comfort.
    # Fold it up later.
    uplevel #0 package require fileutil
    global errorCode errorInfo
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -prefix -directory
	-compare -timestamp -delete -error -progress
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict get $myargs -bucket]} {
	error "Pull requires -bucket" "" [list S3 usage -bucket $args]
    }
    if {![dict exists $myargs -directory]} {
	error "Pull requires -directory" "" [list S3 usage -directory $args]
    }
    # Set default values.
    set defaults "
    -timestamp now
    -compare [S3::Configure -default-compare]
    -prefix {} -delete 0 -error continue -progress ::S3::ignore -blocking 1"
    foreach {key val} $defaults {
	if {![dict exists $myargs $key]} {dict set myargs $key $val}
    }
    # Pull out arguments for convenience
    foreach i {progress prefix directory bucket blocking} {
	set $i [dict get $myargs -$i]
    }
    set prefix [string trimright $prefix /]
    # We're readdy to roll here.
    uplevel 1 [list {*}$progress args $myargs]
    if {[catch {
	set local [S3::getLocal $directory 1]
    } caught]}  {
	error "Pull could not walk local directory - $caught" \
	    $errorInfo $errorCode
    }
    uplevel 1 [list {*}$progress local $local]
    if {[catch {
	set remote [S3::getRemote $bucket $prefix $blocking]
    } caught]} {
	error "Pull could not walk remote directory - $caught" \
	    $errorInfo $errorCode
    }
    uplevel 1 [list {*}$progress remote $remote]
    set result [dict create]
    set result0 [dict create \
	filescopied 0 bytescopied 0 compareskipped 0 \
	errorskipped 0 filesdeleted 0 filesnotdeleted 0]
    foreach suffix $remote {
	uplevel 1 [list {*}$progress copy $suffix start]
	set err [catch {
	    S3::makeDirs $directory $suffix
	    S3::Get -bucket $bucket -blocking $blocking \
	    -file [file join $directory $suffix] \
	    -resource $prefix/$suffix \
	    -timestamp [dict get $myargs -timestamp] \
	    -compare [dict get $myargs -compare]} caught]
	if {$err} {
	    uplevel 1 [list {*}$progress copy $suffix $errorCode]
	    dict incr result0 errorskipped
	    dict set result $suffix $errorCode
	    if {[dict get $myargs -error] eq "throw"} {
		error "Pull failed to Get - $caught" $errorInfo $errorCode
	    } elseif {[dict get $myargs -error] eq "break"} {
		break
	    }
	} else {
	    if {$caught} {
		uplevel 1 [list {*}$progress copy $suffix copied]
		dict incr result0 filescopied
		dict incr result0 bytescopied \
		    [file size [file join $directory $suffix]]
		dict set result $suffix copied
	    } else {
		uplevel 1 [list {*}$progress copy $suffix skipped]
		dict incr result0 compareskipped
		dict set result $suffix skipped
	    }
	}
    }
    # Now do deletes, if so desired
    if {[dict get $myargs -delete]} {
	foreach suffix [lsort -decreasing $local] {
	    # Note, decreasing because we delete empty dirs
	    if {[string match "*/" $suffix]} {
		set f [file join $directory $suffix]
		catch {file delete -- $f}
		if {![file exists $f]} {
		    uplevel 1 [list {*}$progress delete $suffix {}]
		    dict set result $suffix deleted
		    dict incr result0 filesdeleted
		}
	    } elseif {$suffix ni $remote} {
		set err [catch {
		    file delete [file join $directory $suffix]
		} caught]
		if {$err} {
		    uplevel 1 [list {*}$progress delete $suffix $errorCode]
		    dict incr result0 filesnotdeleted
		    dict set result $suffix notdeleted
		} else {
		    uplevel 1 [list {*}$progress delete $suffix {}]
		    dict incr result0 filesdeleted
		    dict set result $suffix deleted
		}
	    }
	}
    }
    dict set result {} $result0
    uplevel 1 [list {*}$progress finished $result]
    return $result
}

# Public. Delete a collection of resources with the same prefix.
proc S3::Toss {args} {
    # This is waaaay to similar to Push for comfort.
    # Fold it up later.
    global errorCode errorInfo
    checkinit
    set myargs [S3::parseargs1 $args {
	-bucket -blocking -prefix
	-error -progress
    }]
    if {![dict exists $myargs -bucket]} {
	dict set myargs -bucket [S3::Configure -default-bucket]
    }
    dict set myargs -bucket [string trim [dict get $myargs -bucket] "/ "]
    if {"" eq [dict get $myargs -bucket]} {
	error "Toss requires -bucket" "" [list S3 usage -bucket $args]
    }
    if {![dict exists $myargs -prefix]} {
	error "Toss requires -prefix" "" [list S3 usage -directory $args]
    }
    # Set default values.
    set defaults "-error continue -progress ::S3::ignore -blocking 1"
    foreach {key val} $defaults {
	if {![dict exists $myargs $key]} {dict set myargs $key $val}
    }
    # Pull out arguments for convenience
    foreach i {progress prefix bucket blocking} {
	set $i [dict get $myargs -$i]
    }
    set prefix [string trimright $prefix /]
    # We're readdy to roll here.
    uplevel 1 [list {*}$progress args $myargs]
    if {[catch {
	set remote [S3::getRemote $bucket $prefix $blocking]
    } caught]} {
	error "Toss could not walk remote bucket - $caught" \
	    $errorInfo $errorCode
    }
    uplevel 1 [list {*}$progress remote $remote]
    set result [dict create]
    set result0 [dict create \
	filescopied 0 bytescopied 0 compareskipped 0 \
	errorskipped 0 filesdeleted 0 filesnotdeleted 0]
    # Now do deletes
    foreach suffix $remote {
	set err [catch {
	    S3::Delete -bucket $bucket -blocking $blocking \
		-resource $prefix/$suffix } caught]
	if {$err} {
	    uplevel 1 [list {*}$progress delete $suffix $errorCode]
	    dict incr result0 filesnotdeleted
	    dict set result $suffix notdeleted
	} else {
	    uplevel 1 [list {*}$progress delete $suffix {}]
	    dict incr result0 filesdeleted
	    dict set result $suffix deleted
	}
    }
    dict set result {} $result0
    uplevel 1 [list {*}$progress finished $result]
    return $result
}
