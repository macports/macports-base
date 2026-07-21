#! /bin/sh

# Delete unneeded (for us) files from the Tcl source distribution.
# Run from vendor/

rm tcl8.*/compat/zlib/doc/crc-doc.1.0.pdf
rm -r tcl8.*/compat/zlib/{amiga,contrib,msdos,nintendods,old,os400,qnx,watcom,win32,win64,win64-arm}
rm -r tcl8.*/pkgs/{sqlite3,itcl,tdbc,thread}*/win
rm -r tcl8.*/win
