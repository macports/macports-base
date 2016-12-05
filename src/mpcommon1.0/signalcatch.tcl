package provide signalcatch 1.0

# Wrap the 'catch' command so that we can decide whether to catch signals
# or propagate them as an error. Default is to propagate; to catch them use
# 'catch -signal ...'
if {[info commands builtin_catch] eq {}} {
    rename catch builtin_catch

    proc catch {args} {
        set catch_signal no
        if {[lindex $args 0] eq "-signal"} {
            set catch_signal yes
            set args [lrange $args 1 end]
        }
        set err [uplevel 1 [list builtin_catch {*}$args]]
        if {$err == 1 && !$catch_signal} {
            set savedErrorCode $::errorCode
            set savedErrorInfo $::errorInfo
            set sigstring "POSIX SIG "
            set len [string length $sigstring]
            if {[string equal -length $len $sigstring $savedErrorCode]} {
                return -code error -errorinfo $savedErrorInfo -errorcode $savedErrorCode "Aborted: [lindex $savedErrorCode end] signal received"
            }
        }
        return $err
    }
}
