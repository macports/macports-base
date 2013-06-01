# This file contains help strings for the various commands/topics in port(1)
#
# Many of these strings are place-holders right now.  Replace with genuinely
# helpful text and then delete this message.
#
# port-help.tcl
# $Id$


set porthelp(activate) {
Activate the given ports

--no-exec   Do not execute any stored pre- or post-activate procedures
}

set porthelp(archive) {
Archive the given ports, i.e. install the port image but do not activate
}

set porthelp(archivefetch) {
Fetch archive for the given ports
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
Removes files associated with the given ports

--archive     Removes temporary archives
--dist        Removes downloaded distfiles
--logs        Removes log files
--work        Removes work directory (default)
--all         Removes everything from above
}

set porthelp(configure) {
Configure the given ports
}

set porthelp(contents) {
Returns a list of files installed by given ports
}

set porthelp(deactivate) {
Deactivates the given ports

--no-exec   Do not execute any stored pre- or post-deactivate procedures
}

set porthelp(dependents) {
Returns a list of installed dependents for each of the given ports

Note: Don't get fooled by the language!
Dependents are those ports which depend on the given port, not vice-versa!
}

set porthelp(rdependents) {
Recursive version of dependents

--full          Display all branches of the tree of dependents instead of only
                showing each port once.
}

set porthelp(deps) {
Display a dependency listing for the given ports

--index         Do not read the Portfile, instead rely solely on the PortIndex
                information. Note this option will prevent the dependencies
                reported from reflecting the effects of any variants specified.
--no-build      Exclude dependencies only required at build time, i.e.
                depends_fetch, depends_extract, and depends_build.
}

set porthelp(rdeps) {
Display a recursive dependency listing for the given ports

--full          Display all branches of the dependency tree instead of only
                showing each port once.
--index         Do not read the Portfile, instead rely solely on the PortIndex
                information. Note this option will prevent the dependencies
                reported from reflecting the effects of any variants specified.
--no-build      Exclude dependencies only required at build time, i.e.
                depends_fetch, depends_extract, and depends_build.
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
Displays short help texts for the given actions
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
Installs the given ports.
    --no-rev-upgrade    Do not run rev-upgrade after the installation.
    --unrequested       Do not mark the port as requested.
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

set porthelp(log) {
Shows main log for given ports

--phase <phase>		Filters by phase (fetch, checksum, extract, patch, configure, build, destroot)
--level <level>	        Filter messages above verbosity level (error, warn, msg, info, debug)
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

set porthelp(notes) {
Displays informational notes for each of the given ports
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

set porthelp(rev-upgrade) {
Scan for broken binaries in the installed ports and rebuild them as needed. Can
be run with -y to only report broken ports, but not automatically rebuild them.

You normally wouldn't have to run rev-upgrade manually; it is run automatically
after each install and upgrade by default. Rev-upgrade doesn't honor package
names, e.g.
	upgrade outdated
will not run rev-upgrade only on outdated, because ports not in outdated might
have been broken by upgrade outdated. Rev-upgrade will always run on all your
active ports.

See man 1 port, section rev-upgrade, and man 5 macports.conf, directives
starting with revupgrade_ for configuration and more information.
}

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
python25, python26, and python31.  The select action lets you set which
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

set porthelp(space) {
Show the disk space used by the given ports

--units <units> Specify units to use. Accepted units are: B, kB, KiB, MB, MiB,
                GB, GiB. The 'B' may be omitted.
--total         Display the grand total only
}

set porthelp(srpm) {
Creates a srpm for each of the given ports
}

set porthelp(setrequested) {
Marks each of the given ports as requested
}

set porthelp(unsetrequested) {
Marks each of the given ports as unrequested
}

set porthelp(sync) {
Synchronize the set of Portfiles
}

set porthelp(test) {
Run tests on each of the given ports
}

set porthelp(unarchive) {
Unarchive the destroot of the given ports from installed images
}

set porthelp(uninstall) {
Uninstall the given ports

--follow-dependents     Recursively uninstall all ports that depend on the
                        specified port before uninstalling the port itself.
--follow-dependencies   Also recursively uninstall all ports that the
                        specified port depended on. This will not uninstall
                        dependencies that are marked as requested or that
                        have other dependents.
--no-exec               Do not execute any stored pre- or post-uninstall
                        procedures.
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
