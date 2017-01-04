This is Darren New's package to interface to amazon's S3 web service.
This is in beta stage, but potentially useful to others already.

Note that test-S3.config should have your own account identifiers 
entered, in order to run the tcltest.

I'm hoping this eventually makes it into TclLib. To that end, I have 
tried to avoid using any packages that aren't widely available on 
all platforms, sticking with tcllib and ActiveState stuff as much 
as possible.

Note that "xsxp.tcl" and associated packaging is necessary for this
system. Plus, there are a few places where I used [dict] and {expand}.
To make this work with 8.5 release, {expand} needs to be changed to {*}.
To make this work with 8.4, you need a Tcl implementation of [dict]
and you need to change {expand} into [eval] and [list] as appropriate.
If you make either of these changes, please bop me back a copy of
the changes <dnew@san.rr.com> and I'll make a new package.

Manifest:

README.txt - this file.
LICENSE.txt - the license for use and redistribution. It's BSD.
S3.man - the beginnings of a Tcl-format man page for S3.
S3.test - The tcltest calls to the S3 package.
  (Note that S3::REST has actually been extensively tested by
   yours truely, but the tests were manual "call the routine, 
   print the results", and I haven't taken time to repackage them
   in Tcltest format. But I will.
test-S3.config - a call to S3::Configure to set your personal
   access identifiers so you can run S3.test.
S3.tsh - The actual source code for the S3 interface package.
xsxp.tcl - Extremely Simple XML Parser. It uses the TclXML package
   to build nested dictionaries, and supplies simple ways of 
   getting to the data. I use it to parse the results from
   S3's bucket listings and such, because I couldn't get TclDOM
   to install on my machine.
xsxp.test - The tcltests for xsxp.
pkgIndex.tcl - For S3 and xsxp.

A few notes:

I expect to break this into several "layers". S3::REST doesn't 
require any XML parsing. The routines dealing with buckets and 
listings parse the XML to return the information in a useful form.

The bucket deletion test code is disabled because Amazon has
been having trouble with bucket creation/deletion leaving
things in an inconsistant state. 

FEEDBACK WELCOME!  -- Please include me in email for any
comments or bug reports about the software.  Thanks!
(I usually don't want to be cc'ed on newsgroup posts, but
this is an exception.)

THANKS!
