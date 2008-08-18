-------------
MacPorts v1.7
-------------

Name:		MacPorts
Version:	1.7 (aka trunk)
Branch:		gsoc08-privileges
Culprit:	pmagrath@macports.org
Stage:		Release Candidate 1
Release Date:	18th August 2008


Welcome
-------

Welcome to RC1 of my gsoc08-privileges branch of MacPorts!


Introduction
------------

The purpose of the gsoc08-privileges branch is to implement facilities to reduce the need to execute MacPorts as root. 

To this end, a number of modifications were made to the MacPorts trunk. The changes have the following effect:

1) MacPorts now performs fetch, extract, patch, configure and build in a user rather than system owned location. By default, this is ~/.macports/opt. This allows MacPorts to do all but the install of the port without root privileges.

2) MacPorts now automatically drops privileges whenever possible so as to avoid running as root whenever possible.

3) MacPorts will prompt for the root password if you attempt to install a port into the /opt hierarchy and did not start MacPorts with sudo. It will not do so however until the install stage. The fetch, extract, patch, configure and build will proceed first under the privileges MacPorts is started with.

4) The Portfile format has a number of new boolean attributes to indicate when an action should or should not be run with root privileges: 'patch.asroot', 'build.asroot', 'configure.asroot', 'destroot.asroot', and 'install.asroot'. The default for all is "no". If the prefix folder (by default /opt/local) is not writable, MacPorts will attempt to elevate privileges to root for the install phase.

5) MacPorts now supports two new, additional, installation options. Each of these is a distinct alternative to the current standard installation option. 
	(a)	A "make group" command has been added to the Makefile and a "--with-shared-directory" switch to the configure script. Running "make group" will create a macports group. "--with-shared-directory" will let let the group specified by "--with-install-group" have full read write access to the /opt/local hierarchy. This will allow users who are members of the new macports group to have full write permissions to /opt and its subfolders, and hence to install ports which only affect that hierarchy to install those ports without requiring root privileges. 
	(b)	 A switch called "--with-no-root-privileges" has been added for use by user installing MacPorts for their own use only. An example configure command would be "./configure --prefix=/Users/{your-user-name-here}/.macports/opt --with-no-root-privileges"


Why Release Candidate 1?
------------------------

On the 11th August, a Beta release was announced on macports-dev and a couple of bugs were shaken out. The code base for the branch is now reasonably well tested and about ready for integration into trunk where it can be tested more fully before the next point release of MacPorts. As such, on the 18th August 2008 (GSoC "pencils down" date) I termed it to be at "Release Candidate" stage.

Where should feedback be directed?
----------------------------------

Please drop me a line with your feedback, either positive or negative, to pmagrath@macports.org.

If you encounter an unexpected error, please include a full debug output and instructions on how to reproduce. 

