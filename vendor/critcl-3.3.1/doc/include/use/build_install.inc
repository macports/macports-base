[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Starting from the [sectref Basics].

[enum] Use an interactive [syscmd tclsh] seesion to determine the value of
[cmd {info library}].

[para] For the purpose of this HowTo assume that this path is
[file /home/aku/opt/ActiveTcl/lib/tcl8.6]

[enum] Invoke the critcl application in a terminal, using [example {

    critcl -libdir /home/aku/opt/ActiveTcl/lib/tcl8.6 -pkg example.tcl

}]

[enum] The package is now build and installed into the chosen directory.

[example {
   % find /home/aku/opt/ActiveTcl/lib/tcl8.6/example/
    /home/aku/opt/ActiveTcl/lib/tcl8.6/example/
    /home/aku/opt/ActiveTcl/lib/tcl8.6/example/pkgIndex.tcl
    /home/aku/opt/ActiveTcl/lib/tcl8.6/example/critcl-rt.tcl
    /home/aku/opt/ActiveTcl/lib/tcl8.6/example/license.terms
    /home/aku/opt/ActiveTcl/lib/tcl8.6/example/linux-x86_64
    /home/aku/opt/ActiveTcl/lib/tcl8.6/example/linux-x86_64/example.so
    /home/aku/opt/ActiveTcl/lib/tcl8.6/example/teapot.txt
}] 

[list_end]
