
In a Windows environment we have the [cmd installer.tcl] script to
perform installation.

[para] If the desired [syscmd tclsh] is associated [file .tcl] files
       then double-clicking / opening the [cmd installer.tcl] is
       enough to invoke it in graphical mode.

       This assumes that [term Tk] is installed and available as well.

[para] Without [term Tk] the only way to invoke the installer are to
       open a DOS window, i.e. [syscmd cmd.exe], and then to invoke
      
[example {
  ./installer.tcl
}]

inside it.
