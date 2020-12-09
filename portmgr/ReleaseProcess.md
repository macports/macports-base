# MacPorts Release Process #

This file documents the evolving MacPorts release process.


## Goals of a Release ##

There are several goals in the release process:

*   Make a specific version of MacPorts available to users.
*   Archive the materials (code, documentation, etc) that compose the release.
*   Replicatability: enable the release to be regenerated.
*   Consistency: codify naming, network locations, etc, for released
    components.
*   Ensure that the user base and public is notified of the release.


## Steps to a Release ##

The following steps to a release are documented in more detail below:

*   Create a release branch to carry the release.
*   Prepare the code for release.
*   Tag the release.
*   Create release products: tarballs and installers.
*   Post release products.
*   Make release version available through selfupdate.
*   Notify public of the release.


### Create a Release Branch ###

For each major release (i.e. 1.9._x_, 2.0._x_, etc.) an appropriate branch is
created with a consistent name. To do this, two things are required:

*   Choose the git revision from which to create the branch, most likely based
    off master.
*   Create the branch (e.g. release-2.0) with git. The following commands
    assume the remote "origin" points to macports/macports-base on GitHub.

        git branch release-2.0 origin/master
        git push origin release-2.0

The actual release, alpha or beta releases, release candidates, and any point
releases will all live on this branch. Releases of any kind will need to be
tagged appropriately and point to commits on this branch.

Only this base repository, not the ports tree kept in another repository, will
be branched for a given release.

Once master is to be used for development of the next major version, increase
its version information to indicate it's moved past the release version by
setting the patch-level version to 99, e.g. 2.0.99 in
[`config/macports_version`][macports_version].


### Prepare the code for Release ###

In preparation for a release, several things should be completed within the
code:

*   Update the file [`ChangeLog`][ChangeLog] in both master and the release
    branch to reflect the appropriate changes.
*   Update the file [`config/macports_version`][macports_version] with the
    target release number. The content of this file is recorded as the
    MacPorts version at MacPorts build time, as displayed by the port command,
    and it's also used by the selfupdate procedure to determine whether
    a newer version of code is available. It should be different between
    master and the release branch, the former greater to differentiate it from
    the latter.
*   Preserve [`config/mp_version`][mp_version] and
    [`config/dp_version`][dp_version] at the 1.800 or 1.710 fixed values,
    respectively, if selfupdate backwards compatibility with old MacPorts
    installations is still desired. (see
    https://trac.macports.org/changeset/43571/trunk/base or [ce8a77c][])
*   Update the autoconf [`configure`][configure] script through the provided
    [`autogen.sh`][autogen.sh] script once the version number in `mp_version`
    has been changed, since the former reads the latter.
*   Regenerate all man pages from scratch to ensure the new version number is
    used in the output file. AsciiDoc and DocBook either need to be installed
    in the target prefix or manually pass the correct paths if they are
    installed elsewhere.

        ./autogen.sh
        ./standard_configure.sh
        make -C doc/ clean all \
            ASCIIDOC=/opt/local/bin/asciidoc \
            XSLTPROC=/opt/local/bin/xsltproc \
            DOCBOOK_XSL=/opt/local/share/xsl/docbook-xsl-nons/manpages/docbook.xsl

*   Make sure that these and any other changes or bug fixes are made on and/or
    merged between the release branch and master as needed. For instance, if
    you've made changes to `ChangeLog` only on the release branch, those
    changes should be merged back into master as well.


### Tag the Release ###

Once the release is ready, it must be tagged so that the release components
may be fetched in the future, to ensure replicability. Generally, a release
candidate is first tagged and built. When and if it is approved as the actual
release, an additional tag is created that names the same sources.

Tagging conventions:

*   v2.0.0-beta2 (beta 2 for release 2.0.0)
*   v2.0.0-rc1 (release candidate 1 for release 2.0.0)
*   v2.0.0 (tagged release 2.0.0)
*   v2.0.1 (2.0.1 release)

We first create an annotated tag pointing to the release branch to make up the
final release. Annotated tags preserve who made the tag and when. Additionally
the tag should be signed with GPG by using the `-s` flag in order to allow
later verification of the signature.

    git tag -a -s v2.0.0 release-2.0
    git push origin v2.0.0

Although only base repository is branched and tagged for a given major
release, we also create a separate tag in the ports tree at the time the final
release tag is created for a major release (_x_._y_.0). This intends to provide
a set of ports intended to work with that release.

    git clone macports/macports-ports macports-ports
    cd macports-ports
    git tag -a -s v2.0.0-archive origin/master
    git push origin v2.0.0-archive


### Create & Post Release Tarballs ###

The release tarballs are .tar.bz2 and .tar.gz archives of the base repository.
They are named with the following naming convention:

    MacPorts-2.0.0.tar.{bz2,gz} (base repository, corresponding to tag v2.0.0)

The following commands issued to the top level Makefile will generate all the
tarballs and checksums:

    make dist DISTVER=2.0.0

The release should be signed with a detached GPG signature in order to allow
cryptographic verification. To do this automatically, use the additional
argument `DISTGPGID` on the make command. The value specifies a key ID either
in hexadecimal format or a email address matching exactly one key. For
details, see [HOW TO SPECIFY A USER ID in gpg(1)][gpg-user-id] for details.

    make dist DISTVER=2.0.0 DISTGPGID=<handle>@macports.org

These tarballs and the checksums are uploaded to the
https://distfiles.macports.org/MacPorts/ directory. At present, this must be
done with the help of the infrastructure team.


### Create Release Packages and Disk Image(s) ###

The dmg is a macOS disk image that contains a standalone installer,
configured in the usual way, named in a consistent fashion and incorporating
the OS version for which it was built.

For 10.6 and newer, we now build flat packages, so an enclosing dmg is not
necessary.

*   MacPorts-2.0.0-10.5-Leopard.dmg
*   MacPorts-2.0.0-10.6-SnowLeopard.pkg
*   MacPorts-2.0.0-10.7-Lion.pkg

To create a pkg or dmg, use the MacPorts port. The Portfile will need to be
updated to incorporate the proper release version and checksums, and the
release tarballs will need to be already uploaded to the downloads section of
the site (wherefrom the sources are fetched by the MacPorts port to build the
pkg for the release). Make sure the ports tree you're using to build the pkgs
is fully up to date.

    sudo port -d pkg MacPorts
    sudo port -d dmg MacPorts

Name each pkg/dmg appropriately, and then sign the pkgs with a Developer ID
(make sure to use the Installer certificate, not the Application one):

    cd work
    mv MacPorts-2.0.0.pkg unsigned/MacPorts-2.0.0-10.7-Lion.pkg
    productsign --sign "Developer ID Installer: John Doe" unsigned/MacPorts-2.0.0-10.7-Lion.pkg MacPorts-2.0.0-10.7-Lion.pkg

(Note that packages signed with Xcode 10 appear to be incompatible with
Mac OS X 10.6.)

For macOS 10.14 Mojave and later, the pkg should also be submitted for
notarization after signing:

    xcrun altool --notarize-app --primary-bundle-id org.macports.base \
        --username <your-apple-id> --password @keychain:altool \
        --file MacPorts-2.0.0-10.14-Mojave.pkg

After notification of successful notarization is received:

    xcrun stapler staple MacPorts-2.5.4-10.14-Mojave.pkg

After signing (and notarizing if applicable), generate checksums, which will
need to be added to the existing checksums file in the downloads directory:

    for type in -md5 -sha1 -ripemd160 -sha256; do
      openssl dgst $type MacPorts-2.0.0-*.{pkg,dmg} >> MacPorts-2.0.0.chk.txt
    done

These new products, along with the new checksums, also have to be posted to
the appropriate directory of the MacPorts distfiles server. Developers are
required to validate the generated installer as thoroughly as possible through
extensive testing, which is mainly why this step of the release process is not
automated through a Makefile target or similar. A good way of validating the
installer is to first create the destroot of the port and examine it for:

*   Linking: libraries and binaries should not be linked against anything
    that's not present by default on a vanilla macOS installation +
    developer tools, excluding even the MacPorts installation prefix; this can
    be accomplished through the use of `otool -L`. Currently the libraries and
    binaries in need of linking validation are:
    *   `${destroot}/opt/local/bin/daemondo`
    *   `${destroot}/opt/local/share/macports/Tcl/darwintrace1.0/darwintrace.dylib`
    *   `${destroot}/opt/local/share/macports/Tcl/macports1.0/MacPorts.dylib`
    *   `${destroot}/opt/local/share/macports/Tcl/pextlib1.0/Pextlib.dylib`
    *   `${destroot}/opt/local/share/macports/Tcl/registry2.0/registry.dylib`
*   Universal building: All the files that need linking confirmation in the
    step above also need to be confirmed to be universal (i386/ppc on 10.5 and
    earlier, i386/x86_64 on 10.6 and later). A way to do this is with the
    `file(1)` command:

        $ file ${destroot}/opt/local/bin/daemondo:
        ${destroot}/opt/local/bin/daemondo: Mach-O universal binary with 2 architectures
        ${destroot}/opt/local/bin/daemondo (for architecture ppc):  Mach-O executable ppc
        ${destroot}/opt/local/bin/daemondo (for architecture i386): Mach-O executable i386

*   tclsh invocation: all scripts installed in `${destroot}/opt/local/bin`
    should invoke the tclsh shell through a call like:

        #!/opt/local/bin/port-tclsh

    thus ensuring that our bundled Tcl interpreter is used in our scripts.
*   Miscellaneous: anything else that might seem out of the ordinary for
    a fully default-configured MacPorts installation.

Once the above requirements have been positively asserted, the one remaining
test is to make sure that the dmg mounts in the Finder when double-clicked,
and that the pkg contained therein properly starts up Installer.app when it's
double-clicked.


### Create Release on GitHub ###

All of our distfiles should also be available as downloads from a new GitHub
release. Create a new release matching the previously created tag on GitHub
and attach all tarballs and installers to it.


### Make the Release Available through Self-Update ###

In order to make the release version available through selfupdate, the
[`config/RELEASE_URL`][RELEASE_URL] file in the base repository needs to be
updated with the tag of the release to distribute. This file is read by the
cron job that makes the code available via rsync. See
[`jobs/mprsyncup`][mprsyncup] in the macports-infrastructure repository.


### Update the branch buildbot uses to generate manpages ###

When releasing a new major version, you should update the buildbot's
[`master.cfg` file][buildbot-master-cfg] so that the single branch scheduler
for the manpage jobs pulls from that new branch. To do that, look for `'man'
in config['deploy']`, locate the `util.ChangeFilter` object passed to the
constructor of `schedulers.SingleBranchScheduler` below that and adjust the
`branch` parameter to the branch you are releasing. Notify ryandesign@ to have
this change deployed on the buildbot.


### Add Release Version to Trac ###

Add the new version to the list of released versions on Trac. Edit the list
using the [web admin interface](https://trac.macports.org/admin/ticket/versions)
on our Trac installation.


### Verify That the Public Rsync Server Has Updated ###

Verify that the MacPorts version on the public rsync server has been updated:

    $ curl -s http://nue.de.rsync.macports.org/macports/release/base/config/macports_version


### Notify the Public of the Release ###

Once the release has been posted, notification of the release should be
sent/posted to the following places:

*   The [macports-announce][]@, [macports-users][]@ and [macports-dev][]@
    mailing lists.
*   The MacPorts website, by adapting the `$macports_version_major` and
    `$macports_version_latest` variables as appropriate in the
    [`includes/common.inc`][common.inc] file in the macports-www repository.
*   The [news section][news] of the website (see the [macports.github.io][]
    repository)
*   The `&macports-version;` entity in
    [`guide/xml/installing.xml`][installing.xml] and
    [`guide/xml/using.xml`][using.xml] in the guide repository.
*   External websites
    *   [SourceForge][]
        (submitter: portmgr@)
    *   [MacUpdate][]
        (submitter: ???)
    *   [Twitter][]
        (submitter: raimue@)
    *   (Where else?)


### Use of new features in Portfiles ###

Using new features introduced by a release should be delayed for 14 days until
being deployed in the ports tree. This should allow users to upgrade their
installations to the new release. This delay matches the warning about
outdated ports tree sources.


[autogen.sh]: /autogen.sh
[ce8a77c]: https://github.com/macports/macports-base/commit/ce8a77c858c679f2d7627a3cd613436b2ead82e7
[ChangeLog]: /ChangeLog
[common.inc]: https://github.com/macports/macports-www/blob/master/includes/common.inc
[configure]: /configure
[dp_version]: /config/dp_version
[gpg-user-id]: https://gnupg.org/documentation/manuals/gnupg/Specify-a-User-ID.html
[installing.xml]: https://github.com/macports/macports-guide/blob/master/guide/xml/installing.xml
[macports-announce]: mailto:macports-announce@lists.macports.org
[macports-dev]: mailto:macports-dev@lists.macports.org
[macports-users]: mailto:macports-users@lists.macports.org
[macports.github.io]: https://github.com/macports/macports.github.io
[macports_version]: /config/macports_version
[MacUpdate]: https://www.macupdate.com/app/mac/21309/macports
[mp_version]: /config/mp_version
[mprsyncup]: https://github.com/macports/macports-infrastructure/blob/master/jobs/mprsyncup
[news]: https://www.macports.org/news
[RELEASE_URL]: /config/RELEASE_URL
[SourceForge]: http://sourceforge.net/projects/macports
[Twitter]: http://twitter.com/macports
[using.xml]: https://github.com/macports/macports-guide/blob/master/guide/xml/using.xml
[buildbot-master-cfg]: https://github.com/macports/macports-infrastructure/blob/master/buildbot/master.cfg

<!-- vim:set fenc=utf-8 ft=markdown tw=78 et sw=4 sts=4: -->
