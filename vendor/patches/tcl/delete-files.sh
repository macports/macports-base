#! /bin/sh

# Delete unneeded (for us) files from the Tcl source distribution.
# Run from vendor/

rm tcl9.*/compat/zlib/doc/crc-doc.1.0.pdf
rm -r tcl9.*/compat/zlib/{amiga,msdos,nintendods,old,os400,qnx,watcom,win32,win64,win64-arm}
for contrib_dir in tcl9.*/compat/zlib/contrib/*; do
    if [ "$(basename "$contrib_dir")" != "minizip" ]; then
        rm -r "$contrib_dir"
    fi
done
rm -r tcl9.*/pkgs/{sqlite3,itcl,tdbc,thread}*/win
rm -r tcl9.*/win
