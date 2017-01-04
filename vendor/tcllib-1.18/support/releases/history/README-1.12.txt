Overview
========

    72  new packages                in 10 modules
    46  changed packages            in 25 modules
    14  internally changed packages in 12 modules
    166 unchanged packages          in 65 modules
    301 packages, total             in 95 modules, total

New in tcllib 1.12
==================

    Module                  Package                         New Version   Comments
    ----------------------- ------------------------------- ------------- -----------------------------------------------
    coroutine               coroutine                       1             Tcl 8.6+ coroutine/event utilities
                            coroutine::auto                 1             s.a.
    ----------------------- ------------------------------- ------------- -----------------------------------------------
    doctools2base           doctools::config                0.1           doctools v2 foundation
                            doctools::html                  0.1
                            doctools::html::cssdefaults     0.1
                            doctools::msgcat                0.1
                            doctools::nroff::man_macros     0.1
                            doctools::paths                 0.1
                            doctools::tcl::parse            0.1
                            doctools::text                  0.1
    ----------------------- ------------------------------- ------------- -----------------------------------------------
    doctools2idx            doctools::idx::export           0.1           doctools v2 index handling
                            doctools::idx::export::docidx   0.1
                            doctools::idx::export::html     0.2
                            doctools::idx::export::json     0.1
                            doctools::idx::export::nroff    0.3
                            doctools::idx::export::text     0.2
                            doctools::idx::export::wiki     0.2
                            doctools::idx::import           0.1
                            doctools::idx::import::docidx   0.1
                            doctools::idx::import::json     0.1
                            doctools::idx::parse            0.1
                            doctools::idx::structure        0.1
                            doctools::msgcat::idx::c        0.1
                            doctools::msgcat::idx::de       0.1
                            doctools::msgcat::idx::en       0.1
                            doctools::msgcat::idx::fr       0.1
    ----------------------- ------------------------------- ------------- -----------------------------------------------
    doctools2toc            doctools::msgcat::toc::c        0.1           doctools v2 TOC handling
                            doctools::msgcat::toc::de       0.1
                            doctools::msgcat::toc::en       0.1
                            doctools::msgcat::toc::fr       0.1
                            doctools::toc::export           0.1
                            doctools::toc::export::doctoc   0.1
                            doctools::toc::export::html     0.1
                            doctools::toc::export::json     0.1
                            doctools::toc::export::nroff    0.2
                            doctools::toc::export::text     0.1
                            doctools::toc::export::wiki     0.1
                            doctools::toc::import           0.1
                            doctools::toc::import::doctoc   0.1
                            doctools::toc::import::json     0.1
                            doctools::toc::parse            0.1
                            doctools::toc::structure        0.1
    ----------------------- ------------------------------- ------------- -----------------------------------------------
    json                    json::write                     1             JSON generation
    math                    math::machineparameters         0.1           Determine double-precision machine parameters
    rest                    rest                            1.0.0         Specify RESTful interfaces to webservices
    ----------------------- ------------------------------- ------------- -----------------------------------------------
    virtchannel_base        tcl::chan::fifo                 1             Various basic reflected/virtual channels
                            tcl::chan::fifo2                1
                            tcl::chan::halfpipe             1
                            tcl::chan::memchan              1
                            tcl::chan::null                 1
                            tcl::chan::nullzero             1
                            tcl::chan::random               1
                            tcl::chan::string               1
                            tcl::chan::textwindow           1
                            tcl::chan::variable             1
                            tcl::chan::zero                 1
                            tcl::randomseed                 1
    ----------------------- ------------------------------- ------------- -----------------------------------------------
    virtchannel_core        tcl::chan::core                 1             Core services for OO based reflected
                            tcl::chan::events               1             channels and transformations
                            tcl::transform::core            1
    ----------------------- ------------------------------- ------------- -----------------------------------------------
    virtchannel_transform   tcl::transform::adler32         1             Various basic channel transforms
                            tcl::transform::base64          1
                            tcl::transform::counter         1
                            tcl::transform::crc32           1
                            tcl::transform::hex             1
                            tcl::transform::identity        1
                            tcl::transform::limitsize       1
                            tcl::transform::observe         1
                            tcl::transform::otp             1
                            tcl::transform::rot             1
                            tcl::transform::spacer          1
                            tcl::transform::zlib            1
    ----------------------- ------------------------------- ------------- -----------------------------------------------

Changes from tcllib 1.11.1 to 1.12
==================================

                                                 tcllib 1.11.1   tcllib 1.12
    Module         Package                       Old Version     New Version   Comments
    -------------- ----------------------------- --------------- ------------- ------------
    base64         base64                        2.4             2.4.1         B
                   uuencode                      1.1.4           1.1.5         B
                   yencode                       1.1.2           1.1.3         B
    -------------- ----------------------------- --------------- ------------- ------------
    comm           comm                          4.5.7           4.6.1         EF B
    -------------- ----------------------------- --------------- ------------- ------------
    crc            cksum                         1.1.2           1.1.3         B
                   crc32                         1.3             1.3.1         B D
    -------------- ----------------------------- --------------- ------------- ------------
    dns            ip                            1.1.2           1.1.3         B
    -------------- ----------------------------- --------------- ------------- ------------
    doctools       doctools                      1.4             1.4.3         B
                   doctools::idx                 1               1.0.3         D B API
                   doctools::idx                                 2             D B API
                   doctools::toc                 1               1.1.2         D B EF API
                   doctools::toc                                 2             D B EF API
    -------------- ----------------------------- --------------- ------------- ------------
    doctools2idx   doctools::idx                 1               1.0.3         API
                   doctools::idx                                 2             API
    -------------- ----------------------------- --------------- ------------- ------------
    doctools2toc   doctools::toc                 1               1.1.2         API
                   doctools::toc                                 2             API
    -------------- ----------------------------- --------------- ------------- ------------
    fileutil       fileutil                      1.13.5          1.14.2        EF B
                   fileutil::multi::op           0.5.2           0.5.3         B
                   fileutil::traverse            0.4             0.4.1         B
    -------------- ----------------------------- --------------- ------------- ------------
    grammar_fa     grammar::fa                   0.3             0.4           EF B
    htmlparse      htmlparse                     1.1.3           1.2           I
    jpeg           jpeg                          0.3.3           0.3.5         B
    json           json                          1.0             1.0.1         B T
    -------------- ----------------------------- --------------- ------------- ------------
    log            log                           1.2.1           1.3           I B D
                   logger                        0.8             0.9           EF
    -------------- ----------------------------- --------------- ------------- ------------
    math           math                          1.2.4           1.2.5         B
                   math::geometry                1.0.3           1.0.4         B
                   math::interpolate             1.0.2           1.0.3         B
                   math::linearalgebra           1.1             1.1.3         B T
                   math::statistics              0.6             0.6.3         B
    -------------- ----------------------------- --------------- ------------- ------------
    nmea           nmea                          0.2.0                         API
                   nmea                                          1.0.0         API
    -------------- ----------------------------- --------------- ------------- ------------
    pluginmgr      pluginmgr                     0.2             0.3           EF
    pop3           pop3                          1.6.3           1.7           EF T
    -------------- ----------------------------- --------------- ------------- ------------
    ripemd         ripemd128                     1.0.3           1.0.4         B
                   ripemd160                     1.0.3           1.0.4         B
    -------------- ----------------------------- --------------- ------------- ------------
    snit           snit                          1.3.1           1.4.1         EF B
                   snit                          2.2.1           2.3.1         EF B
    -------------- ----------------------------- --------------- ------------- ------------
    stringprep     stringprep                    1.0.0           1.0.1         B
                   stringprep::data              1.0.0           1.0.1         B
    -------------- ----------------------------- --------------- ------------- ------------
    struct         struct::graph                 1.2.1           1.2.1         EF B
                   struct::graph                 2.3.1           2.4           EF B
                   struct::graph::op             0.9             0.11.3        EF
                   struct::stack                 1.3.3           1.4           EF
                   struct::tree                  1.2.2           1.2.2         B
                   struct::tree                  2.1.1           2.1.2         B
    -------------- ----------------------------- --------------- ------------- ------------
    tar            tar                           0.4             0.6           EF
    -------------- ----------------------------- --------------- ------------- ------------
    transfer       transfer::connect             0.1             0.2           EF I
                   transfer::copy                0.2             0.3           I B
                   transfer::data::destination   0.1             0.2           EF I
                   transfer::data::source        0.1             0.2           EF I
                   transfer::receiver            0.1             0.2           EF I
                   transfer::transmitter         0.1             0.2           EF I
    -------------- ----------------------------- --------------- ------------- ------------
    wip            wip                           1.1.1           1.1.2         B
                   wip                           2.1.1           2.1.2         B
    -------------- ----------------------------- --------------- ------------- ------------
    yaml           huddle                        0.1.3           0.1.4         B D T
                   yaml                          0.3.3           0.3.5         B D T
    -------------- ----------------------------- --------------- ------------- ------------

Invisible changes (documentation, testsuites)
=============================================

                                tcllib 1.11.1   tcllib 1.12
    Module     Package          Old Version     New Version   Comments
    ---------- ---------------- --------------- ------------- ----------
    aes        aes              1.0.1           1.0.1         D
    control    control          0.1.3           0.1.3         T
    crc        sum              1.1.0           1.1.0         critcl
    csv        csv              0.7.1           0.7.1         D
    ---------- ---------------- --------------- ------------- ----------
    docstrip   docstrip         1.2             1.2           D
               docstrip::util   1.2             1.2           D
    ---------- ---------------- --------------- ------------- ----------
    md4        md4              1.0.5           1.0.5         critcl
    ---------- ---------------- --------------- ------------- ----------
    md5        md5              1.4.4           1.4.4         critcl
               md5              2.0.7           2.0.7         critcl
    ---------- ---------------- --------------- ------------- ----------
    md5crypt   md5crypt         1.1.0           1.1.0         critcl
    pop3d      pop3d            1.1.0           1.1.0         D T
    rc4        rc4              1.1.0           1.1.0         critcl
    ---------- ---------------- --------------- ------------- ----------
    sha1       sha1             1.1.0           1.1.0         critcl
               sha1             2.0.3           2.0.3         critcl
               sha256           1.0.2           1.0.2         critcl
    ---------- ---------------- --------------- ------------- ----------
    struct     struct::list     1.7             1.7           T
    ---------- ---------------- --------------- ------------- ----------

Unchanged
=========

    asn, autoproxy, base32, base32::core, base32::hex, bee, bench,
    bench::in, bench::out::csv, bench::out::text, bibtex, blowfish,
    cache::async, calendar, cmdline, counter, crc16, des, dns,
    doctools::changelog, doctools::cvs, exif,
    fileutil::magic::cfront, fileutil::magic::cgen,
    fileutil::magic::filetype, fileutil::magic::mimetype,
    fileutil::magic::rt, fileutil::multi, ftp, ftp::geturl, ftpd,
    grammar::fa::dacceptor, grammar::fa::dexec, grammar::fa::op,
    grammar::me::cpu, grammar::me::cpu::core,
    grammar::me::cpu::gasm, grammar::me::tcl, grammar::me::util,
    grammar::peg, grammar::peg::interp, html, ident, inifile,
    interp, interp::delegate::method, interp::delegate::proc, irc,
    javascript, ldap, ldapx, logger::appender, logger::utils,
    map::slippy, map::slippy::cache, map::slippy::fetcher, mapproj,
    math::bigfloat, math::bignum, math::calculus,
    math::complexnumbers, math::constants, math::fourier,
    math::fuzzy, math::optimize, math::polynomials,
    math::rationalfunctions, math::roman, math::special, mime,
    multiplexer, nameserv, nameserv::auto, nameserv::common,
    nameserv::server, ncgi, nntp, otp, page::analysis::peg::emodes,
    page::analysis::peg::minimize, page::analysis::peg::reachable,
    page::analysis::peg::realizable, page::compiler::peg::mecpu,
    page::gen::peg::canon, page::gen::peg::cpkg, page::gen::peg::hb,
    page::gen::peg::me, page::gen::peg::mecpu, page::gen::peg::ser,
    page::gen::tree::text, page::parse::lemon, page::parse::peg,
    page::parse::peghb, page::parse::pegser, page::pluginmgr,
    page::util::flow, page::util::norm::lemon,
    page::util::norm::peg, page::util::peg, page::util::quote,
    picoirc, png, pop3d::dbox, pop3d::udb, profiler, rcs, report,
    resolv, S3, SASL, SASL::NTLM, SASL::XGoogleToken,
    simulation::annealing, simulation::montecarlo,
    simulation::random, smtp, smtpd, soundex, spf, stooop, struct,
    struct::disjointset, struct::matrix, struct::pool,
    struct::prioqueue, struct::queue, struct::record, struct::set,
    struct::skiplist, switched, tclDES, tclDESjr, term,
    term::interact::menu, term::interact::pager, term::receive,
    term::receive::bind, term::send, textutil, textutil::adjust,
    textutil::expander, textutil::repeat, textutil::split,
    textutil::string, textutil::tabify, textutil::trim, tie,
    tie::std::array, tie::std::dsource, tie::std::file,
    tie::std::growfile, tie::std::log, tie::std::rarray, tiff, time,
    transfer::copy::queue, treeql, uevent, uevent::onidle, unicode,
    unicode::data, units, uri, uri::urn, uuid, xsxp

Legend  Change  Details Comments
        ------  ------- ---------
        Major   API:    ** incompatible ** API changes.

        Minor   EF :    Extended functionality, API.
                I  :    Major rewrite, but no API change

        Patch   B  :    Bug fixes.
                EX :    New examples.
                P  :    Performance enhancement.

        None    T  :    Testsuite changes.
                D  :    Documentation updates.
    
