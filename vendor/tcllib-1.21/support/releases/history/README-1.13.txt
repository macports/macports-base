Overview
========

    44  new packages                in 10  modules
    29  changed packages            in 24  modules
    62  internally changed packages in 11  modules
    207 unchanged packages          in 79  modules
    348 packages, total             in 103 modules, total

New in tcllib 1.13
==================

    Module           Package                              New Version   Comments
    ---------------- ------------------------------------ ------------- ----------
    base64           ascii85                              1.0
    gpx              gpx                                  1
    ---------------- ------------------------------------ ------------- ----------
    grammar_aycock   grammar::aycock                      1.0
                     grammar::aycock::debug               1.0
                     grammar::aycock::runtime             1.0
    ---------------- ------------------------------------ ------------- ----------
    hook             hook                                 0.1
    imap4            imap4                                0.3
    ---------------- ------------------------------------ ------------- ----------
    math             math::calculus::symdiff              1.0
                     math::numtheory                      1.0
    ---------------- ------------------------------------ ------------- ----------
    namespacex       namespacex                           0.1
    pki              pki                                  0.1
    ---------------- ------------------------------------ ------------- ----------
    pt               char                                 1
                     configuration                        1
                     paths                                1
                     pt::ast                              1.1
                     pt::cparam::configuration::critcl    1.0.1
                     pt::parse::peg                       1
                     pt::pe                               1
                     pt::pe::op                           1
                     pt::peg                              1
                     pt::peg::container                   1
                     pt::peg::container::peg              1
                     pt::peg::export                      1
                     pt::peg::export::container           1
                     pt::peg::export::json                1
                     pt::peg::export::peg                 1
                     pt::peg::from::json                  1
                     pt::peg::from::peg                   1
                     pt::peg::import                      1
                     pt::peg::import::json                1
                     pt::peg::interp                      1
                     pt::peg::op                          1
                     pt::peg::to::container               1
                     pt::peg::to::cparam                  1.0.1
                     pt::peg::to::json                    1
                     pt::peg::to::param                   1
                     pt::peg::to::peg                     1
                     pt::peg::to::tclparam                1
                     pt::pgen                             1
                     pt::rde                              1.0.1
                     pt::tclparam::configuration::snit    1.0.1
                     pt::tclparam::configuration::tcloo   1.0.1
                     text::write                          1
    ---------------- ------------------------------------ ------------- ----------
    tepam            tepam                                0.2.0
    ---------------- ------------------------------------ ------------- ----------

Changes from tcllib 1.12 to 1.13
================================

                                         tcllib 1.12   tcllib 1.13
    Module         Package               Old Version   New Version   Comments
    -------------- --------------------- ------------- ------------- ----------
    aes            aes                   1.0.1         1.0.2         B
    asn            asn                   0.8.3         0.8.4         B
    base64         base64                2.4.1         2.4.2         D B
    cmdline        cmdline               1.3.1         1.3.2         D B
    comm           comm                  4.6.1         4.6.2         B
    csv            csv                   0.7.1         0.7.2         D B
    dns            ip                    1.1.3         1.2           EF
    docstrip       docstrip::util        1.2           1.3           D EF B
    -------------- --------------------- ------------- ------------- ----------
    doctools       doctools              1.4.3         1.4.11        EF B
                   doctools::idx         1.0.3         1.0.4         B
                   doctools::idx         2             2             B
                   doctools::toc         1.1.2         1.1.3         B
                   doctools::toc         2             2             B
    -------------- --------------------- ------------- ------------- ----------
    doctools2idx   doctools::idx         1.0.3         1.0.4         B
                   doctools::idx         2             2             B
    -------------- --------------------- ------------- ------------- ----------
    doctools2toc   doctools::toc         1.1.2         1.1.3         B
                   doctools::toc         2             2             B
    -------------- --------------------- ------------- ------------- ----------
    fileutil       fileutil              1.14.2        1.14.4        B EF
    ftpd           ftpd                  1.2.4         1.2.5         B
    json           json                  1.0.1         1.1.1         I B
    map            map::slippy           0.2           0.3           B
    -------------- --------------------- ------------- ------------- ----------
    math           math::fuzzy           0.2           0.2.1         B
                   math::geometry        1.0.4         1.1.2         EF B D
                   math::linearalgebra   1.1.3         1.1.4         B
                   math::statistics      0.6.3         0.7.0         EF T
    -------------- --------------------- ------------- ------------- ----------
    pop3           pop3                  1.7           1.8           EF
    sha1           sha256                1.0.2         1.0.3         B
    -------------- --------------------- ------------- ------------- ----------
    snit           snit                  1.4.1         1.4.2         D B
                   snit                  2.3.1         2.3.2         D B
    -------------- --------------------- ------------- ------------- ----------
    struct         struct::list          1.7           1.8           EF T D
                   struct::queue         1.4.1         1.4.2         I T
                   struct::stack         1.4           1.5.1         EF I
    -------------- --------------------- ------------- ------------- ----------
    tar            tar                   0.6           0.7           EF
    units          units                 2.1           2.1.1         B
    -------------- --------------------- ------------- ------------- ----------
    wip            wip                   1.1.2         1.2           EF
                   wip                   2.1.2         2.2           EF
    -------------- --------------------- ------------- ------------- ----------
    yaml           huddle                0.1.4         0.1.5         B
    -------------- --------------------- ------------- ------------- ----------

Invisible changes (documentation, testsuites)
=============================================

                                                            tcllib 1.12   tcllib 1.13
    Module                  Package                         Old Version   New Version   Comments
    ----------------------- ------------------------------- ------------- ------------- ----------
    coroutine               coroutine                       1             1             D
                            coroutine::auto                 1             1             D
    ----------------------- ------------------------------- ------------- ------------- ----------
    doctools2base           doctools::msgcat                0.1           0.1           D
    ----------------------- ------------------------------- ------------- ------------- ----------
    doctools2idx            doctools::idx::export           0.1           0.1           D
                            doctools::idx::export::docidx   0.1           0.1           D
                            doctools::idx::export::html     0.2           0.2           D
                            doctools::idx::export::json     0.1           0.1           D
                            doctools::idx::export::nroff    0.3           0.3           D
                            doctools::idx::export::text     0.2           0.2           D
                            doctools::idx::export::wiki     0.2           0.2           D
                            doctools::idx::import           0.1           0.1           D
                            doctools::idx::import::docidx   0.1           0.1           D
                            doctools::idx::import::json     0.1           0.1           D
                            doctools::msgcat::idx::c        0.1           0.1           D
                            doctools::msgcat::idx::de       0.1           0.1           D
                            doctools::msgcat::idx::en       0.1           0.1           D
                            doctools::msgcat::idx::fr       0.1           0.1           D
    ----------------------- ------------------------------- ------------- ------------- ----------
    doctools2toc            doctools::msgcat::toc::c        0.1           0.1           D
                            doctools::msgcat::toc::de       0.1           0.1           D
                            doctools::msgcat::toc::en       0.1           0.1           D
                            doctools::msgcat::toc::fr       0.1           0.1           D
                            doctools::toc::export           0.1           0.1           D
                            doctools::toc::export::doctoc   0.1           0.1           D
                            doctools::toc::export::html     0.1           0.1           D
                            doctools::toc::export::json     0.1           0.1           D
                            doctools::toc::export::nroff    0.2           0.2           D
                            doctools::toc::export::text     0.1           0.1           D
                            doctools::toc::export::wiki     0.1           0.1           D
                            doctools::toc::import           0.1           0.1           D
                            doctools::toc::import::doctoc   0.1           0.1           D
                            doctools::toc::import::json     0.1           0.1           D
    ----------------------- ------------------------------- ------------- ------------- ----------
    http                    autoproxy                       1.5.1         1.5.1         D
    mime                    smtp                            1.4.5         1.4.5         D
    simulation              simulation::random              0.1           0.1           D
    struct                  struct::graph::op               0.11.3        0.11.3        D T
    ----------------------- ------------------------------- ------------- ------------- ----------
    virtchannel_base        tcl::chan::fifo                 1             1             D
                            tcl::chan::fifo2                1             1             D
                            tcl::chan::halfpipe             1             1             D
                            tcl::chan::memchan              1             1             D
                            tcl::chan::null                 1             1             D
                            tcl::chan::nullzero             1             1             D
                            tcl::chan::random               1             1             D
                            tcl::chan::string               1             1             D
                            tcl::chan::textwindow           1             1             D
                            tcl::chan::variable             1             1             D
                            tcl::chan::zero                 1             1             D
                            tcl::randomseed                 1             1             D
    ----------------------- ------------------------------- ------------- ------------- ----------
    virtchannel_core        tcl::chan::core                 1             1             D
                            tcl::chan::events               1             1             D
                            tcl::transform::core            1             1             D
    ----------------------- ------------------------------- ------------- ------------- ----------
    virtchannel_transform   tcl::transform::adler32         1             1             D
                            tcl::transform::base64          1             1             D
                            tcl::transform::counter         1             1             D
                            tcl::transform::crc32           1             1             D
                            tcl::transform::hex             1             1             D
                            tcl::transform::identity        1             1             D
                            tcl::transform::limitsize       1             1             D
                            tcl::transform::observe         1             1             D
                            tcl::transform::otp             1             1             D
                            tcl::transform::rot             1             1             D
                            tcl::transform::spacer          1             1             D
                            tcl::transform::zlib            1             1             D
    ----------------------- ------------------------------- ------------- ------------- ----------

Unchanged
=========

    base32, base32::core, base32::hex, bee, bench, bench::in,
    bench::out::csv, bench::out::text, bibtex, blowfish,
    cache::async, calendar, cksum, control, counter, crc16, crc32,
    des, dns, docstrip, doctools::changelog, doctools::config,
    doctools::cvs, doctools::html, doctools::html::cssdefaults,
    doctools::idx::parse, doctools::idx::structure,
    doctools::nroff::man_macros, doctools::paths,
    doctools::tcl::parse, doctools::text, doctools::toc::parse,
    doctools::toc::structure, exif, fileutil::magic::cfront,
    fileutil::magic::cgen, fileutil::magic::filetype,
    fileutil::magic::mimetype, fileutil::magic::rt, fileutil::multi,
    fileutil::multi::op, fileutil::traverse, ftp, ftp::geturl,
    grammar::fa, grammar::fa::dacceptor, grammar::fa::dexec,
    grammar::fa::op, grammar::me::cpu, grammar::me::cpu::core,
    grammar::me::cpu::gasm, grammar::me::tcl, grammar::me::util,
    grammar::peg, grammar::peg::interp, html, htmlparse, ident,
    inifile, interp, interp::delegate::method,
    interp::delegate::proc, irc, javascript, jpeg, json::write,
    ldap, ldapx, log, logger, logger::appender, logger::utils,
    map::slippy::cache, map::slippy::fetcher, mapproj, math,
    math::bigfloat, math::bignum, math::calculus,
    math::complexnumbers, math::constants, math::fourier,
    math::interpolate, math::machineparameters, math::optimize,
    math::polynomials, math::rationalfunctions, math::roman,
    math::special, md4, md5, md5crypt, mime, multiplexer, nameserv,
    nameserv::auto, nameserv::common, nameserv::server, ncgi, nmea,
    nntp, otp, page::analysis::peg::emodes,
    page::analysis::peg::minimize, page::analysis::peg::reachable,
    page::analysis::peg::realizable, page::compiler::peg::mecpu,
    page::gen::peg::canon, page::gen::peg::cpkg, page::gen::peg::hb,
    page::gen::peg::me, page::gen::peg::mecpu, page::gen::peg::ser,
    page::gen::tree::text, page::parse::lemon, page::parse::peg,
    page::parse::peghb, page::parse::pegser, page::pluginmgr,
    page::util::flow, page::util::norm::lemon,
    page::util::norm::peg, page::util::peg, page::util::quote,
    picoirc, pluginmgr, png, pop3d, pop3d::dbox, pop3d::udb,
    profiler, rc4, rcs, report, resolv, rest, ripemd128, ripemd160,
    S3, SASL, SASL::NTLM, SASL::XGoogleToken, sha1,
    simulation::annealing, simulation::montecarlo, smtpd, soundex,
    spf, stooop, stringprep, stringprep::data, struct,
    struct::disjointset, struct::graph, struct::matrix,
    struct::pool, struct::prioqueue, struct::record, struct::set,
    struct::skiplist, struct::tree, sum, switched, tclDES, tclDESjr,
    term, term::interact::menu, term::interact::pager,
    term::receive, term::receive::bind, term::send, textutil,
    textutil::adjust, textutil::expander, textutil::repeat,
    textutil::split, textutil::string, textutil::tabify,
    textutil::trim, tie, tie::std::array, tie::std::dsource,
    tie::std::file, tie::std::growfile, tie::std::log,
    tie::std::rarray, tiff, time, transfer::connect, transfer::copy,
    transfer::copy::queue, transfer::data::destination,
    transfer::data::source, transfer::receiver,
    transfer::transmitter, treeql, uevent, uevent::onidle, unicode,
    unicode::data, uri, uri::urn, uuencode, uuid, xsxp, yaml,
    yencode

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
    
