Introduction
============

Tcllib 2.0 is the first major revision of Tcllib after a long series of
minor 1.x releases.

This revision

  1. __drops support__ for Tcl versions before 8.5.

       - All packages now require Tcl 8.5 as their minimum runtime.

       - This does not mean that the implementations are already changed to use
         Tcl 8.5 features.

       - Such changes will be done incrementally.

       - Users of Tcl 8.4 or even older still have Tcllib 1.21 available to them.

  2. __adds support__ for Tcl 9, for both Tcl and C implementations
     (where available).

       - It is the first revision to have such support.

       - Tcllib 1.21 and older will not work with Tcl 9.

  3. enhances the visibility of the __C accelerators__ available for various
     Tcllib packages through the adjunct __Tcllibc__ binary package.

     Tcllibc's version has become 2.0 also, to match Tcllib itself.

       - The Makefile's `install` target is extended to install both Tcllib and
         Tcllibc.

	 In other words, Tcllibc is now __built by default__, requiring a Critcl
	 installation.

	 Eben so, Tcllibc is __still optional__, and Tcllib can still be built
	 and installed without it.

       - To install only Tcllib use the new target `install-tcl`.

       - To install only Tcllibc use the new target `install-binaries`.

       - __Beware__ that Tcllibc, as a binary package, has to be compiled for
         either Tcl 8 or Tcl 9.

       - __Beware__, that the Tcllibc binary package requires Tcl 8.6 as its
       	 minimum runtime.
	 This is due to the Tcl 9 portability support, which requires 8.6 on the
       	 other side of the border.
	 This should not be true hardship.
	 Tcllib 1.21 is still available, and does not have this restriction.

Further documentation, including more detailed instructions on how to build and
install Tcllib/Tcllibc, is available at <https://core.tcl-lang.org/tcllib>

Overview
========

    1   new packages     in 1   modules
    440 changed packages in 131 modules
    450 packages, total  in 132 modules, total

Legend
======

    Change   Details   Comments
    -------- --------- ----------------------------------
    Major    API       __incompatible__ API changes
    Minor    EF        Extended functionality, API
             I         Major rewrite, but no API change
    Patch    B         Bug fixes
             EX        New examples
             P         Performance enhancement
    None     T         Testsuite changes
             D         Documentation updates
    -------- --------- ----------------------------------

New in Tcllib 2.0
=================

    Module   Package      New Version   Comments
    -------- ------------ ------------- ----------
    try      file::home   1
    -------- ------------ ------------- ----------

Deprecations in Tcllib 2.0
===========================

Four packages are stage 3 deprecated in favor of two replacements.
This means that these packages are now fully removed from Tcllib.

    Module             Package           Replacement      Deprecation stage
    ------------------ ----------------- ---------------- --------------------------------
    doctools           doctools::paths   fileutil::paths  (D3) Attempts to use throw errors
    doctools           doctools::config  struct::map      (D3) Attempts to use throw errors
    pt                 paths             fileutil::paths  (D3) Attempts to use throw errors
    pt                 configuration     struct::map      (D3) Attempts to use throw errors
    ------------------ ----------------- ---------------- --------------------------------

Future progress:

  - Nothing anymore, until other new deprecations come up

Changes from Tcllib 1.21 to 2.0
===============================

    Module                  Package                              From 1.21   To 2.0    Comments
    ----------------------- ------------------------------------ ----------- --------- ------------
    aes                     aes                                  1.2.1       1.2.2     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    amazon-s3               S3                                   1.0.3       1.0.5     T
                            xsxp                                 1.0         1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    asn                     asn                                  0.8.4       0.8.5     T
    ----------------------- ------------------------------------ ----------- --------- ------------
    base32                  base32                               0.1         0.2       D I T
                            base32::core                         0.1         0.2       D I T
                            base32::hex                          0.1         0.2       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    base64                  ascii85                              1.0         1.1.1     D I T
                            base64                               2.5         2.6.1     B D EF T
                            uuencode                             1.1.5       1.1.6     D I T
                            yencode                              1.1.3       1.1.4     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    bee                     bee                                  0.1         0.3       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    bench                   bench                                0.4         0.6       D I T
                            bench::in                            0.1         0.2       D I T
                            bench::out::csv                      0.1.2       0.1.3     D I T
                            bench::out::text                     0.1.2       0.1.3     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    bibtex                  bibtex                               0.7         0.8       T
    blowfish                blowfish                             1.0.5       1.0.6     D I T
    cache                   cache::async                         0.3.1       0.3.2     D I T
    calendar                calendar                             0.2         0.4       D I T
    clay                    clay                                 0.8.6       0.8.8     T
    ----------------------- ------------------------------------ ----------- --------- ------------
    clock                   clock::iso8601                       0.1         0.2       D
                            clock::rfc2822                       0.1         0.2       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    cmdline                 cmdline                              1.5.2       1.5.3     B D T
    comm                    comm                                 4.7         4.7.3     B I T
    control                 control                              0.1.3       0.1.4     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    coroutine               coroutine                            1.3         1.4       B D I
                            coroutine::auto                      1.2         1.3       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    counter                 counter                              2.0.4       2.0.6     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    crc                     cksum                                1.1.4       1.1.5     D I T
                            crc16                                1.1.4       1.1.5     B D EF T
                            crc32                                1.3.3       1.3.4     B D T
                            sum                                  1.1.2       1.1.3     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    cron                    cron                                 2.1         2.2       D I T
    csv                     csv                                  0.8.1       0.10      B I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    debug                   debug                                1.0.6       1.0.7     D I
                            debug::caller                        1.1         1.2       D I
                            debug::heartbeat                     1.0.1       1.0.2     D I
                            debug::timestamp                     1           1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    defer                   defer                                1           1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    des                     des                                  1.1.0       1.2       D I T
                            tclDES                               1.0.0       1.1       D I T
                            tclDESjr                             1.0.0       1.1       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    dicttool                dicttool                             1.1         1.2       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    dns                     dns                                  1.5.0       1.6.1     D EF T
                            ip                                   1.4         1.5.1     D I T
                            resolv                               1.0.3       1.0.4     I
                            spf                                  1.1.1       1.1.2     I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    docstrip                docstrip                             1.2         1.3       D I T
                            docstrip::util                       1.3.1       1.3.3     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    doctools                doctools                             1.5.6       1.6.1     B D EF I T
                            doctools::changelog                  1.1         1.2       D I
                            doctools::cvs                        1           1.1       D I
                            doctools::idx                        1.1         1.2.1     D I T
                            doctools::idx                        2           2.1       D I T
                            doctools::toc                        1.2         1.3.1     D I T
                            doctools::toc                        2           2         D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    doctools2base           doctools::html                       0.1         0.2       I
                            doctools::html::cssdefaults          0.1         0.2       D I
                            doctools::msgcat                     0.1         0.2       D I T
                            doctools::nroff::man_macros          0.1         0.2       D I
                            doctools::tcl::parse                 0.1         0.2       D I T
                            doctools::text                       0.1         0.2       I
    ----------------------- ------------------------------------ ----------- --------- ------------
    doctools2idx            doctools::idx                        1.1         1.2.1     D I T
                            doctools::idx                        2           2.1       D I T
                            doctools::idx::export                0.2.1       0.2.2     D I T
                            doctools::idx::export::docidx        0.1         0.2       D I T
                            doctools::idx::export::html          0.2         0.3       D I T
                            doctools::idx::export::json          0.1         0.2       D I T
                            doctools::idx::export::nroff         0.3         0.4       D I T
                            doctools::idx::export::text          0.2         0.3       D I T
                            doctools::idx::export::wiki          0.2         0.3       D I T
                            doctools::idx::import                0.2.1       0.2.2     I T
                            doctools::idx::import::docidx        0.1         0.2       I T
                            doctools::idx::import::json          0.1         0.2       I T
                            doctools::idx::parse                 0.1         0.2       I T
                            doctools::idx::structure             0.1         0.2       I T
                            doctools::msgcat::idx::c             0.1         0.2       I
                            doctools::msgcat::idx::de            0.1         0.2       I
                            doctools::msgcat::idx::en            0.1         0.2       I
                            doctools::msgcat::idx::fr            0.1         0.2       I
    ----------------------- ------------------------------------ ----------- --------- ------------
    doctools2toc            doctools::msgcat::toc::c             0.1         0.2       I
                            doctools::msgcat::toc::de            0.1         0.2       I
                            doctools::msgcat::toc::en            0.1         0.2       I
                            doctools::msgcat::toc::fr            0.1         0.2       I
                            doctools::toc                        1.2         1.3.1     D I T
                            doctools::toc                        2           2         D I T
                            doctools::toc::export                0.2.1       0.2.2     D I T
                            doctools::toc::export::doctoc        0.1         0.2       D I T
                            doctools::toc::export::html          0.1         0.2       D I T
                            doctools::toc::export::json          0.1         0.2       D I T
                            doctools::toc::export::nroff         0.2         0.3       D I T
                            doctools::toc::export::text          0.1         0.2       D I T
                            doctools::toc::export::wiki          0.1         0.2       D I T
                            doctools::toc::import                0.2.1       0.2.2     D I T
                            doctools::toc::import::doctoc        0.1         0.2       I T
                            doctools::toc::import::json          0.1         0.2       I T
                            doctools::toc::parse                 0.1         0.2       D I T
                            doctools::toc::structure             0.1         0.2       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    dtplite                 dtplite                              1.3.1       1.3.2     D I
    exif                    exif                                 1.1.2       1.1.4     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    fileutil                fileutil                             1.16.1      1.16.3    B D T
                            fileutil::decode                     0.2.1       0.2.2     I
                            fileutil::multi                      0.1         0.2       D I T
                            fileutil::multi::op                  0.5.3       0.5.4     D I T
                            fileutil::paths                      1           1.1       D I T
                            fileutil::traverse                   0.6         0.7       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    ftp                     ftp                                  2.4.13      2.4.14    D I
                            ftp::geturl                          0.2.2       0.2.3     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    ftpd                    ftpd                                 1.3         1.4.1     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    fumagic                 fileutil::magic::cfront              1.3.0       1.3.2     B
                            fileutil::magic::cgen                1.3.0       1.3.1     B
                            fileutil::magic::filetype            2.0.1       2.0.2     B
                            fileutil::magic::rt                  3.0         3.1       B
    ----------------------- ------------------------------------ ----------- --------- ------------
    generator               generator                            0.2         0.3       B D
    gpx                     gpx                                  1           1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    grammar_aycock          grammar::aycock                      1.0         1.1       D I
                            grammar::aycock::debug               1.0         1.1       D I
                            grammar::aycock::runtime             1.0         1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    grammar_fa              grammar::fa                          0.5         0.6       D I T
                            grammar::fa::dacceptor               0.1.1       0.1.2     D I T
                            grammar::fa::dexec                   0.2         0.3       D I T
                            grammar::fa::op                      0.4.1       0.4.2     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    grammar_me              grammar::me::cpu                     0.2         0.3       D I T
                            grammar::me::cpu::core               0.2         0.4       D I T
                            grammar::me::cpu::gasm               0.1         0.2       D I
                            grammar::me::tcl                     0.1         0.2       D I T
                            grammar::me::util                    0.1         0.2       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    grammar_peg             grammar::peg                         0.2         0.3       D I
                            grammar::peg::interp                 0.1.1       0.1.2     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    hook                    hook                                 0.2         0.3       B D T
    html                    html                                 1.5         1.6       D I T
    htmlparse               htmlparse                            1.2.2       1.2.3     D I T
    http                    autoproxy                            1.7         1.8.1     D I T
    httpd                   httpd                                4.3.5       4.3.6     B T
    httpwget                http::wget                           0.1         0.2.1     I
    ident                   ident                                0.42        0.44      D I T
    imap4                   imap4                                0.5.3       0.5.5     D I
    inifile                 inifile                              0.3.2       0.3.3     B T
    ----------------------- ------------------------------------ ----------- --------- ------------
    interp                  interp                               0.1.2       0.1.3     D I T
                            interp::delegate::method             0.2         0.3       D I T
                            interp::delegate::proc               0.2         0.3       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    irc                     irc                                  0.7.0       0.8.0     I
                            picoirc                              0.13.0      0.14.0    B D EF I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    javascript              javascript                           1.0.2       1.0.3     D I
    jpeg                    jpeg                                 0.5         0.7       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    json                    json                                 1.3.4       1.3.6     D I T
                            json::write                          1.0.4       1.0.5     D EF
    ----------------------- ------------------------------------ ----------- --------- ------------
    lambda                  lambda                               1           1.1       D I
    lazyset                 lazyset                              1           1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    ldap                    ldap                                 1.10.1      1.10.2    B D
                            ldapx                                1.2         1.3       EF
    ----------------------- ------------------------------------ ----------- --------- ------------
    log                     log                                  1.4         1.5       D I T
                            logger                               0.9.4       0.9.5     D I T
                            logger::appender                     1.3         1.4       D I
                            logger::utils                        1.3.1       1.3.2     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    map                     map::geocode::nominatim              0.1         0.3       D I
                            map::slippy                          0.5         0.10      D EF I T
                            map::slippy::cache                   0.2         0.5       D I
                            map::slippy::fetcher                 0.4         0.7       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    mapproj                 mapproj                              1.0         1.1       I
    markdown                Markdown                             1.2.2       1.2.4     B D EF T
    ----------------------- ------------------------------------ ----------- --------- ------------
    math                    math                                 1.2.5       1.2.6     D I
                            math::bigfloat                       1.2.3                 B D T
                            math::bigfloat                       2.0.3       2.0.6     B D T
                            math::bignum                         3.1.1       3.1.2     D I
                            math::calculus                       0.8.2                 D I T
                            math::calculus                                   1.1       D I T
                            math::calculus::symdiff              1.0.1       1.0.2     D I T
                            math::changepoint                    0.1         0.2       D I
                            math::combinatorics                  2.0         2.1       D I
                            math::complexnumbers                 1.0.2       1.0.3     D I
                            math::constants                      1.0.2       1.0.4     D I
                            math::decimal                        1.0.4       1.0.5     B D T
                            math::exact                          1.0.1       1.0.2     D I T
                            math::figurate                       1.0         1.1       D I
                            math::filters                        0.1         0.3       D I
                            math::fourier                        1.0.2       1.0.3     D I
                            math::fuzzy                          0.2.1       0.2.2     D T
                            math::geometry                       1.4.1       1.4.2     B D EF T
                            math::interpolate                    1.1.2       1.1.4     D I
                            math::linearalgebra                  1.1.6       1.1.7     D I T
                            math::machineparameters              0.1         0.2       D I
                            math::numtheory                      1.1.3       1.1.4     B D EF T
                            math::optimize                       1.0.1       1.0.2     D I T
                            math::PCA                            1.0         1.1       D I
                            math::polynomials                    1.0.1       1.0.2     D I
                            math::probopt                        1.0         1.1       D I
                            math::quasirandom                    1.0         1.1       D I
                            math::rationalfunctions              1.0.1       1.0.2     D I
                            math::roman                          1.0         1.1       D T
                            math::special                        0.5.2       0.5.4     D EF I T
                            math::statistics                     1.5.0       1.6.1     D I T
                            math::trig                           1.0         1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    md4                     md4                                  1.0.7       1.0.8     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    md5                     md5                                  1.4.5       1.4.6     I
                            md5                                  2.0.8       2.0.9     I
    ----------------------- ------------------------------------ ----------- --------- ------------
    md5crypt                md5crypt                             1.1.0       1.2.0     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    mime                    mime                                 1.7.0       1.7.2     T
                            smtp                                 1.5.1       1.5.2     T
    ----------------------- ------------------------------------ ----------- --------- ------------
    mkdoc                   mkdoc                                0.7.0       0.7.2     D I
    multiplexer             multiplexer                          0.2         0.3       D I T
    namespacex              namespacex                           0.3         0.4       B T
    ncgi                    ncgi                                 1.4.4       1.4.6     D I T
    nettool                 nettool                              0.5.2       0.5.4     D I
    nmea                    nmea                                 1.0.0       1.1.0     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    nns                     nameserv                             0.4.2       0.4.3     D I
                            nameserv::auto                       0.3         0.4       D I
                            nameserv::common                     0.1         0.2       D I
                            nameserv::server                     0.3.2       0.3.3     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    nntp                    nntp                                 0.2.1       0.2.3     D I
    ntp                     time                                 1.2.1       1.2.2     D I T
    oauth                   oauth                                1.0.3       1.0.4     D I
    oodialect               oo::dialect                          0.3.3       0.3.4     I
    ----------------------- ------------------------------------ ----------- --------- ------------
    oometa                  oo::meta                             0.7.1       0.7.2     D I
                            oo::option                           0.3.1       0.3.2     I
    ----------------------- ------------------------------------ ----------- --------- ------------
    ooutil                  oo::util                             1.2.2       1.2.3     D I
    otp                     otp                                  1.0.0       1.1.0     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    page                    page::analysis::peg::emodes          0.1         0.2       I
                            page::analysis::peg::minimize        0.1         0.2       I
                            page::analysis::peg::reachable       0.1         0.2       I
                            page::analysis::peg::realizable      0.1         0.2       I
                            page::compiler::peg::mecpu           0.1.1       0.1.2     I
                            page::config::peg                    0.1         0.2       I
                            page::gen::peg::canon                0.1         0.2       I
                            page::gen::peg::cpkg                 0.1         0.2       I
                            page::gen::peg::hb                   0.1         0.2       I
                            page::gen::peg::me                   0.1         0.2       I
                            page::gen::peg::mecpu                0.1         0.2       I
                            page::gen::peg::ser                  0.1         0.2       I
                            page::gen::tree::text                0.1         0.2       I
                            page::parse::lemon                   0.1         0.2       I
                            page::parse::peg                     0.1         0.2       I
                            page::parse::peghb                   0.1         0.2       I
                            page::parse::pegser                  0.1         0.2       I
                            page::pluginmgr                      0.2         0.3       I
                            page::reader::hb                     0.1         0.2       I
                            page::reader::lemon                  0.1         0.2       I
                            page::reader::peg                    0.1         0.2       I
                            page::reader::ser                    0.1         0.2       I
                            page::reader::treeser                0.1         0.2       I
                            page::transform::mecpu               0.1         0.2       I
                            page::transform::reachable           0.1         0.2       I
                            page::transform::realizable          0.1         0.2       I
                            page::util::flow                     0.1         0.2       I
                            page::util::norm::lemon              0.1         0.2       I
                            page::util::norm::peg                0.1         0.2       I
                            page::util::peg                      0.1         0.2       I
                            page::util::quote                    0.1         0.2       I
                            page::writer::hb                     0.1         0.2       I
                            page::writer::identity               0.1         0.2       I
                            page::writer::me                     0.1         0.2       I
                            page::writer::mecpu                  0.1.1       0.1.2     I
                            page::writer::null                   0.1         0.2       I
                            page::writer::peg                    0.1         0.2       I
                            page::writer::ser                    0.1         0.2       I
                            page::writer::tpc                    0.1         0.2       I
                            page::writer::tree                   0.1         0.2       I
    ----------------------- ------------------------------------ ----------- --------- ------------
    pki                     pki                                  0.20        0.22      B EF T
    pluginmgr               pluginmgr                            0.3         0.5       D I
    png                     png                                  0.3         0.4.1     D I T
    pop3                    pop3                                 1.10        1.11      EF
    ----------------------- ------------------------------------ ----------- --------- ------------
    pop3d                   pop3d                                1.1.0       1.2.0     D I
                            pop3d::dbox                          1.0.2       1.0.3     D I
                            pop3d::udb                           1.1         1.2       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    practcl                 clay                                 0.8.6       0.8.8     ---
                            practcl                              0.16.4      0.16.6    D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    processman              odie::processman                     0.6         0.8       B D
                            processman                           0.6         0.8       B D
    ----------------------- ------------------------------------ ----------- --------- ------------
    profiler                profiler                             0.6         0.7       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    pt                      char                                 1.0.2       1.0.3     I T
                            pt::ast                              1.1         1.2       D I T
                            pt::cparam::configuration::critcl    1.0.2       1.0.3     D I T
                            pt::cparam::configuration::tea       0.1         0.2       D I T
                            pt::parse::peg                       1.0.1       1.0.3     D I T
                            pt::pe                               1.0.2       1.0.3     D I T
                            pt::pe::op                           1.0.1       1.0.2     D I T
                            pt::peg                              1           1.1.1     D I T
                            pt::peg::container                   1           1.1       D I T
                            pt::peg::container::peg              1           1.1.1     D I
                            pt::peg::export                      1.0.1       1.0.2     D I T
                            pt::peg::export::container           1           1.1       I T
                            pt::peg::export::json                1           1.1       I T
                            pt::peg::export::peg                 1           1.1       I T
                            pt::peg::from::json                  1           1.1       D I T
                            pt::peg::from::peg                   1.0.3       1.0.4     D I T
                            pt::peg::import                      1.0.1       1.0.2     D I T
                            pt::peg::import::json                1           1.1       D I T
                            pt::peg::import::peg                 1           1.1       D I T
                            pt::peg::interp                      1.0.1       1.0.2     D I T
                            pt::peg::op                          1.1.0       1.2.0     D I T
                            pt::peg::to::container               1           1.1       D I T
                            pt::peg::to::cparam                  1.1.3       1.1.4     D I T
                            pt::peg::to::json                    1           1.1       D I T
                            pt::peg::to::param                   1.0.1       1.0.2     D I T
                            pt::peg::to::peg                     1.0.2       1.0.3     D I T
                            pt::peg::to::tclparam                1.0.3       1.0.4     D I T
                            pt::pgen                             1.1         1.4       D I T
                            pt::rde                              1.1         1.2       D I T
                            pt::rde::nx                          1.1.1.1     1.2.1.2   I
                            pt::rde::oo                          1.1         1.2       I
                            pt::tclparam::configuration::nx      1.0.1       1.0.2     D I T
                            pt::tclparam::configuration::snit    1.0.2       1.0.3     D I T
                            pt::tclparam::configuration::tcloo   1.0.4       1.0.5     D I T
                            pt::util                             1.1         1.2       D I
                            text::write                          1           1.1       I
    ----------------------- ------------------------------------ ----------- --------- ------------
    rc4                     rc4                                  1.1.0       1.2.0     D I T
    rcs                     rcs                                  0.1         0.2       D I T
    report                  report                               0.3.2       0.5       B D I T
    rest                    rest                                 1.5         1.7       D EF
    ----------------------- ------------------------------------ ----------- --------- ------------
    ripemd                  ripemd128                            1.0.5       1.0.6     D I T
                            ripemd160                            1.0.5       1.0.7     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    sasl                    SASL                                 1.3.3       1.3.4     D I T
                            SASL::NTLM                           1.1.2       1.1.4     D I T
                            SASL::SCRAM                          0.1         0.2       D I T
                            SASL::XGoogleToken                   1.0.1       1.0.2     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    sha1                    sha1                                 1.1.1       1.1.2     D I T
                            sha1                                 2.0.4       2.0.5     D I T
                            sha256                               1.0.4       1.0.6     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    simulation              simulation::annealing                0.2         0.3       D I
                            simulation::montecarlo               0.1         0.2       D I
                            simulation::random                   0.4.0       0.5.0     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    smtpd                   smtpd                                1.5         1.6       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    snit                    snit                                 1.4.2       1.4.3     D I T
                            snit                                 2.3.2       2.3.4     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    soundex                 soundex                              1.0         1.1       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    stooop                  stooop                               4.4.1       4.4.2     D I T
                            switched                             2.2.1       2.2.2     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    string                  string::token                        1           1.1       D I
                            string::token::shell                 1.2         1.3       D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    stringprep              stringprep                           1.0.1       1.0.3     D I T
                            stringprep::data                     1.0.1       1.0.3     D I
                            unicode                              1.0.0       1.1.1     D I T
                            unicode::data                        1.0.0       1.1.1     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    struct                  struct                               1.4         1.5       ---
                            struct                               2.1         2.2       ---
                            struct::disjointset                  1.1         1.2       D I
                            struct::graph                        1.2.1       1.2.2     D I T
                            struct::graph                        2.4.3       2.4.4     D I T
                            struct::graph::op                    0.11.3      0.11.4    D I
                            struct::list                         1.8.5       1.9       B D T
                            struct::list::test                   1.8.4       1.8.5     I
                            struct::map                          1           1.1       I T
                            struct::matrix                       1.2.2                 D I T
                            struct::matrix                       2.0.4       2.2       D I T
                            struct::pool                         1.2.3       1.2.4     D I T
                            struct::prioqueue                    1.4         1.5       D I T
                            struct::queue                        1.4.5       1.4.6     D I T
                            struct::record                       1.2.2       1.2.4     D I T
                            struct::set                          2.2.3       2.2.5     D I T
                            struct::skiplist                     1.3         1.4       D I T
                            struct::stack                        1.5.3       1.5.4     D I T
                            struct::tree                         1.2.2       1.2.3     D I T
                            struct::tree                         2.1.2       2.1.3     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    tar                     tar                                  0.11        0.13      D EF
    ----------------------- ------------------------------------ ----------- --------- ------------
    tepam                   tepam                                0.5.2       0.5.4     D I T
                            tepam::doc_gen                       0.1.1       0.1.3     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    term                    term                                 0.1         0.2       D I
                            term::ansi::code                     0.2         0.3       D I
                            term::ansi::code::attr               0.1         0.2       D I
                            term::ansi::code::ctrl               0.3         0.4       B D
                            term::ansi::code::macros             0.1         0.2       D I
                            term::ansi::ctrl::unix               0.1.1       0.1.2     D I
                            term::ansi::send                     0.2         0.3       D I
                            term::interact::menu                 0.1         0.2       D I
                            term::interact::pager                0.1         0.2       D I
                            term::receive                        0.1         0.2       D I
                            term::receive::bind                  0.1         0.2       D I
                            term::send                           0.1         0.2       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    textutil                textutil                             0.9         0.10      I
                            textutil::adjust                     0.7.3       0.7.4     D I T
                            textutil::expander                   1.3.1       1.3.2     D I
                            textutil::patch                      0.1         0.2       D I T
                            textutil::repeat                     0.7         0.8       D I
                            textutil::split                      0.8         0.9       I
                            textutil::string                     0.8         0.9       I
                            textutil::tabify                     0.7         0.8       D I
                            textutil::trim                       0.7         0.8       D I
                            textutil::wcswidth                   35.1        35.3      D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    tie                     tie                                  1.2         1.3       EF T
                            tie::std::array                      1.1         1.2       D EF T
                            tie::std::dsource                    1.1         1.2       D EF T
                            tie::std::file                       1.1         1.2       D EF T
                            tie::std::growfile                   1.1         1.2       D EF T
                            tie::std::log                        1.1         1.2       D EF T
                            tie::std::rarray                     1.1         1.2       D EF T
    ----------------------- ------------------------------------ ----------- --------- ------------
    tiff                    tiff                                 0.2.1       0.2.3     D I T
    tool                    tool                                 0.7         0.8       I
    ----------------------- ------------------------------------ ----------- --------- ------------
    transfer                transfer::connect                    0.2         0.3       D I
                            transfer::copy                       0.3         0.4       D I
                            transfer::copy::queue                0.1         0.2       D I
                            transfer::data::destination          0.2         0.3       D I
                            transfer::data::source               0.2         0.3       D I
                            transfer::receiver                   0.2         0.3       D I
                            transfer::transmitter                0.2         0.3       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    treeql                  treeql                               1.3.1       1.3.2     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    try                     throw                                1           1.1       D I
                            try                                  1           1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    udpcluster              udpcluster                           0.3.3       0.3.4     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    uev                     uevent                               0.3.1       0.3.2     D I T
                            uevent::onidle                       0.1         0.2       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    units                   units                                2.2.1       2.2.3     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    uri                     uri                                  1.2.7       1.2.8     D I T
                            uri::urn                             1.0.3       1.0.4     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    uuid                    uuid                                 1.0.7       1.0.9     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    valtype                 valtype::common                      1           1.1       D I
                            valtype::creditcard::amex            1           1.1       D I
                            valtype::creditcard::discover        1           1.1       D I
                            valtype::creditcard::mastercard      1           1.1       D I
                            valtype::creditcard::visa            1           1.1       D I
                            valtype::gs1::ean13                  1           1.1       D I
                            valtype::iban                        1.7         1.8       D I T
                            valtype::imei                        1           1.1       D I
                            valtype::isbn                        1           1.1       D I
                            valtype::luhn                        1           1.1       D I
                            valtype::luhn5                       1           1.1       D I
                            valtype::usnpi                       1           1.1       D I
                            valtype::verhoeff                    1           1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    virtchannel_base        tcl::chan::cat                       1.0.3       1.0.4     D I
                            tcl::chan::facade                    1.0.1       1.0.2     D I
                            tcl::chan::fifo                      1           1.1       D I
                            tcl::chan::fifo2                     1           1.1       D I T
                            tcl::chan::halfpipe                  1.0.2       1.0.3     D EF
                            tcl::chan::memchan                   1.0.4       1.0.5     D I T
                            tcl::chan::null                      1           1.1       D I
                            tcl::chan::nullzero                  1           1.1       D I
                            tcl::chan::random                    1           1.1       D I
                            tcl::chan::std                       1.0.1       1.0.2     D I
                            tcl::chan::string                    1.0.3       1.0.4     D I
                            tcl::chan::textwindow                1           1.1       D I
                            tcl::chan::variable                  1.0.4       1.0.5     D I T
                            tcl::chan::zero                      1           1.1       D I
                            tcl::randomseed                      1           1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    virtchannel_core        tcl::chan::core                      1           1.1       D I
                            tcl::chan::events                    1           1.1       D I
                            tcl::transform::core                 1           1.1       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    virtchannel_transform   tcl::transform::adler32              1           1.1       D I
                            tcl::transform::base64               1           1.1       D I
                            tcl::transform::counter              1           1.1       D I
                            tcl::transform::crc32                1           1.1       D I
                            tcl::transform::hex                  1           1.1       D I
                            tcl::transform::identity             1           1.1       D I
                            tcl::transform::limitsize            1           1.1       D I
                            tcl::transform::observe              1           1.1       D I
                            tcl::transform::otp                  1           1.1       D I
                            tcl::transform::rot                  1           1.1       D I
                            tcl::transform::spacer               1           1.1       D I
                            tcl::transform::zlib                 1.0.1       1.0.2     D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    websocket               websocket                            1.4.2       1.6       B
    ----------------------- ------------------------------------ ----------- --------- ------------
    wip                     wip                                  1.2         1.3       D I
                            wip                                  2.2         2.3       D I
    ----------------------- ------------------------------------ ----------- --------- ------------
    yaml                    huddle                               0.4         0.5       B D T
                            huddle::json                         0.1         0.2       I
                            yaml                                 0.4.1       0.4.2     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------
    zip                     zipfile::decode                      0.9         0.10.1    B D EF
                            zipfile::encode                      0.4         0.5.1     D I
                            zipfile::mkzip                       1.2.1       1.2.4     D I T
    ----------------------- ------------------------------------ ----------- --------- ------------

