# This file contains help strings for the various commands/topics in port(1)
#
# Many of these strings are place-holders right now.  Replace with genuinely
# helpful text and then delete this message.
#
# port-help.tcl
# $Id$


set porthelp(activate) {
Activate the given ports
}

set porthelp(archive) {
Archive the given ports
}

set porthelp(build) {
Build the given ports
}

set porthelp(cat) {
Writes the Portfiles of the given ports to stdout
}

set porthelp(cd) {
Changes to the directory of the given port

Only in interactive mode.
}

set porthelp(checksum) {
Compares the checksums for the downloaded files of the given ports
}

set porthelp(clean) {
Removes file associates with given ports

--archive     Removes created archives
--dist        Removes downloaded distfiles
--work        Removes work directory (default)
--all         Removes everything from above
--logs 				Removes log files for port
}

set porthelp(log) {
Shows main log for given ports

--phase <phase>		Filteres log file by phase (configure, fetch, etc..)
--verbosity <ver>	Filteres log file by verbosity level (msg, debug, info)	
}

set porthelp(configure) {
Configure the given ports
}

set porthelp(contents) {
Returns a list of files installed by given ports
}

set porthelp(deactivate) {
Deactivates the given ports
}

set porthelp(dependents) {
Returns a list of installed dependents for each of the given ports

Note: Don't get fooled by the language!
Dependents are those ports which depend on the given port, not vice-versa!
}

set porthelp(deps) {
This action is an alias for 'info --pretty --fullname --depends'
}

set porthelp(destroot) {
Destroot the given ports
}

set porthelp(dir) {
Returns the directories of the given ports

This can be quite handy to be used in your shell:
cd $(port dir <portname>)
}

set porthelp(distcheck) {
Checks if the given ports can be fetched from all of its master_sites
}

set porthelp(distfiles) {
Returns a list of distfiles for the given port
}

set porthelp(dmg) {
Creates a dmg for each of the given ports
}

set porthelp(dpkg) {
Creates a dpkg for each of the given ports
}

set porthelp(echo) {
Returns the list of ports the argument expands to

This can be useful to see what a pseudo-port expression expands to.
}

set porthelp(edit) {
Edit given ports
}

set porthelp(ed) $porthelp(edit)

set porthelp(exit) {
Exit port

Only in interactive mode.
}

set porthelp(extract) {
Extract the downloaded files of the given ports
}

set porthelp(fetch) {
Downloaded distfiles for the given ports
}

set porthelp(file) {
Returns the path to the Portfile for each of the given ports
}

set porthelp(gohome) {
Opens the homepages of the given ports in your browser
}

set porthelp(help) {
Displays short help texts for the given commands
}

set porthelp(info) {
Returns information about the given ports. Most of the options specify a field
to be included in the resulting report. Multiple fields may be specified, in
which case all will be included.  If no fields are specified, a useful default
set will be used.  The other options which do not correspond to fields are:
   --depends   An abbreviation for all depends_* fields
   --index     Do not read the Portfile, instead rely solely on the index
               information. Note this option will prevent the information
               reported from reflecting the effects of any variants specified.
   --line      Report on each port on a single line, with fields separated
               by spaces.  Handy for automatically processing the output of
               info called on a large number of ports.
   --pretty    Format the output in a convenient, human-readable fashion. Note
               that this option is the default when no options are specified to
               info.
}

set porthelp(install) {
Installs the given ports
}

set porthelp(installed) {
List installed versions of the given port, or all installed ports if no port is given
}

set porthelp(lint) {
Checks if the Portfile is lint-free for each of the given ports
}

set porthelp(list) {
List the available version for each of the given ports
}

set porthelp(livecheck) {
Checks if a new version of the software is available
}

set porthelp(load) {
Interface to launchctl(1) for ports providing startup items
}

set porthelp(location) {
Returns the install location for each of the given ports
}

set porthelp(mdmg) {
Creates a dmg containing an mpkg for each of the given ports and their dependencies
}

set porthelp(mirror) {
Fetches distfiles for the given ports
}

set porthelp(mpkg) {
Creates an mpkg for each of the given ports and their dependencies
}

set porthelp(outdated) {
Returns a list of outdated ports
}

set porthelp(patch) {
Applies patches to each of the given ports
}

set porthelp(pkg) {
Creates a pkg for each of the given ports
}

set porthelp(platform) {
Returns the current platform that port is running on
}

set porthelp(provides) {
Return which port provides each of the files given
}

set porthelp(quit) $porthelp(exit)

set porthelp(rpm) {
Creates a rpm for each of the given ports
}

set porthelp(search) {
Search for a port

--case-sensitive   match the search string in a case-sensitive manner
--exact   match the literal search string exactly
--glob    treat the given search string as a glob (default)
--line    print each result on a single line
--regex   treat the given search string as a regular expression
--<field> match against <field>, default is '--name --description'
}

set porthelp(select) {
Select between multiple versions of a versioned port

This allows you to choose which version, among several installed versions
of a port, is to be considered primary.  What this means is which version
becomes the one most would consider the default, e.g. the one run without
specifying any version.

One example is the set of python ports, where there are (among others)
python25, python26, and python30.  The select command lets you set which
of these becomes the version run when you simply use 'python'.

<arguments> must include the group upon which to be acted, and may include
a version if --set is used.

--list   List available versions for the group
--set    Select the given version for the group
--show   Show which version is currently selected for the group (default if
         none given)
}

set porthelp(selfupdate) {
Upgrade MacPorts itself and run the sync target
}

set porthelp(srpm) {
Creates a srpm for each of the given ports
}

set porthelp(submit) {
Submit a port to the MacPorts Web Application (unimplemented)
}

set porthelp(sync) {
Synchronize the set of Portfiles
}

set porthelp(test) {
Run tests on each of the given ports
}

set porthelp(unarchive) {
Unarchive the given ports
}

set porthelp(uninstall) {
Uninstall the given ports
}

set porthelp(unload) $porthelp(load)

set porthelp(upgrade) {
Upgrades the given ports to the latest version. Respects global options
-n, -R, and -u (see the port man page).  Note that in selecting variants
to use in the upgraded build of the port, the order of precedence is variants
specified on the command line, then variants active in the latest installed
version of the port, then the variants.conf file.

--force             Ignore circumstances that would normally cause ports to be
                    skipped (e.g. not outdated).
--enforce-variants  If the installed variants do not match those requested,
                    upgrade even if the port is not outdated.
--no-replace        Do not replace one port with another according to the
                    replaced_by field
}

set porthelp(url) {
Returns the URL for each of the given ports
}

set porthelp(usage) {
Returns basic usage of the port command
}

set porthelp(variants) {
Returns a list of variants provided by the given ports, with descriptions if present
}

set porthelp(version) {
Returns the version of MacPorts
}
