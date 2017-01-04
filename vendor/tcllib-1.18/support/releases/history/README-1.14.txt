Overview
========

    21  new packages                in 7   modules
    30  changed packages            in 24  modules
    8   internally changed packages in 8   modules
    328 unchanged packages          in 89  modules
    393 packages, total             in 107 modules, total

New in tcllib 1.14
==================

    Module             Package                           New Version   Comments
    ------------------ --------------------------------- ------------- ----------
    lambda             lambda                            1
    math               math::decimal                     1.0.2         T
    ooutil             oo::util                          1
    pt                 pt::peg::import::peg              1
    try                try                               1
    ------------------ --------------------------------- ------------- ----------
    valtype            valtype::common                   1
                       valtype::creditcard::amex         1
                       valtype::creditcard::discover     1
                       valtype::creditcard::mastercard   1
                       valtype::creditcard::visa         1
                       valtype::gs1::ean13               1
                       valtype::iban                     1
                       valtype::imei                     1
                       valtype::isbn                     1
                       valtype::luhn                     1
                       valtype::luhn5                    1
                       valtype::usnpi                    1
                       valtype::verhoeff                 1
    ------------------ --------------------------------- ------------- ----------
    virtchannel_base   tcl::chan::cat                    1.0.1
                       tcl::chan::facade                 1.0.1
                       tcl::chan::std                    1.0.1
    ------------------ --------------------------------- ------------- ----------

Changes from tcllib 1.13 to 1.14
================================

                                                            tcllib 1.13   tcllib 1.14
    Module             Package                              Old Version   New Version   Comments
    ------------------ ------------------------------------ ------------- ------------- ----------
    cmdline            cmdline                              1.3.2         1.3.3         B T
    ------------------ ------------------------------------ ------------- ------------- ----------
    coroutine          coroutine                            1             1.1           B
                       coroutine::auto                      1             1.1           B
    ------------------ ------------------------------------ ------------- ------------- ----------
    csv                csv                                  0.7.2         0.7.3         B D T
    doctools           doctools                             1.4.11        1.4.13        B T
    fileutil           fileutil::traverse                   0.4.1         0.4.2         B
    ftp                ftp                                  2.4.9         2.4.11        B
    ftpd               ftpd                                 1.2.5         1.2.6         B
    grammar_peg        grammar::peg::interp                 0.1           0.1.1         B
    inifile            inifile                              0.2.3         0.2.4         B
    interp             interp                               0.1.1         0.1.2         B
    jpeg               jpeg                                 0.3.5         0.4.0         I D
    ------------------ ------------------------------------ ------------- ------------- ----------
    json               json                                 1.1.1         1.1.2         B T
                       json::write                          1             1.0.1         B
    ------------------ ------------------------------------ ------------- ------------- ----------
    map                map::slippy                          0.3           0.4           B D T
    pki                pki                                  0.1           0.2           B T
    ------------------ ------------------------------------ ------------- ------------- ----------
    pt                 pt::pgen                             1             1.0.1         B
                       pt::rde                              1.0.1         1.0.2         B T
                       pt::tclparam::configuration::tcloo   1.0.1         1.0.2         B T
    ------------------ ------------------------------------ ------------- ------------- ----------
    rest               rest                                 1.0.0         1.0           ---
    simulation         simulation::random                   0.1           0.3           B D
    smtpd              smtpd                                1.4.0         1.5           EF
    struct             struct::list                         1.8           1.8.1         B
    term               term::ansi::ctrl::unix               0.1           0.1.1         B
    textutil           textutil::adjust                     0.7           0.7.1         B
    uri                uri                                  1.2.1         1.2.2         B
    ------------------ ------------------------------------ ------------- ------------- ----------
    virtchannel_base   tcl::chan::memchan                   1             1.0.2         B
                       tcl::chan::string                    1             1.0.1         B
                       tcl::chan::variable                  1             1.0.2         B
    ------------------ ------------------------------------ ------------- ------------- ----------
    yaml               yaml                                 0.3.5         0.3.6         B
    ------------------ ------------------------------------ ------------- ------------- ----------

Invisible changes (documentation, testsuites)
=============================================

                                                      tcllib 1.13   tcllib 1.14
    Module        Package                             Old Version   New Version   Comments
    ------------- ----------------------------------- ------------- ------------- ----------
    base64        base64                              2.4.2         2.4.2         T
    hook          hook                                0.1           0.1           D
    math          math::linearalgebra                 1.1.4         1.1.4         D
    multiplexer   multiplexer                         0.2           0.2           T
    pop3          pop3                                1.8           1.8           T
    pop3d         pop3d                               1.1.0         1.1.0         T
    pt            pt::cparam::configuration::critcl   1.0.1         1.0.1         T
    tepam         tepam                               0.2.0         0.2.0         T
    ------------- ----------------------------------- ------------- ------------- ----------

Unchanged
=========

    aes, ascii85, asn, autoproxy, base32, base32::core, base32::hex,
    bee, bench, bench::in, bench::out::csv, bench::out::text,
    bibtex, blowfish, cache::async, calendar, char, cksum, comm,
    configuration, control, counter, crc16, crc32, des, dns,
    docstrip, docstrip::util, doctools::changelog, doctools::config,
    doctools::cvs, doctools::html, doctools::html::cssdefaults,
    doctools::idx, doctools::idx, doctools::idx::export,
    doctools::idx::export::docidx, doctools::idx::export::html,
    doctools::idx::export::json, doctools::idx::export::nroff,
    doctools::idx::export::text, doctools::idx::export::wiki,
    doctools::idx::import, doctools::idx::import::docidx,
    doctools::idx::import::json, doctools::idx::parse,
    doctools::idx::structure, doctools::msgcat,
    doctools::msgcat::idx::c, doctools::msgcat::idx::de,
    doctools::msgcat::idx::en, doctools::msgcat::idx::fr,
    doctools::msgcat::toc::c, doctools::msgcat::toc::de,
    doctools::msgcat::toc::en, doctools::msgcat::toc::fr,
    doctools::nroff::man_macros, doctools::paths,
    doctools::tcl::parse, doctools::text, doctools::toc,
    doctools::toc, doctools::toc::export,
    doctools::toc::export::doctoc, doctools::toc::export::html,
    doctools::toc::export::json, doctools::toc::export::nroff,
    doctools::toc::export::text, doctools::toc::export::wiki,
    doctools::toc::import, doctools::toc::import::doctoc,
    doctools::toc::import::json, doctools::toc::parse,
    doctools::toc::structure, exif, fileutil,
    fileutil::magic::cfront, fileutil::magic::cgen,
    fileutil::magic::filetype, fileutil::magic::mimetype,
    fileutil::magic::rt, fileutil::multi, fileutil::multi::op,
    ftp::geturl, gpx, grammar::aycock, grammar::aycock::debug,
    grammar::aycock::runtime, grammar::fa, grammar::fa::dacceptor,
    grammar::fa::dexec, grammar::fa::op, grammar::me::cpu,
    grammar::me::cpu::core, grammar::me::cpu::gasm,
    grammar::me::tcl, grammar::me::util, grammar::peg, html,
    htmlparse, huddle, ident, imap4, interp::delegate::method,
    interp::delegate::proc, ip, irc, javascript, ldap, ldapx, log,
    logger, logger::appender, logger::utils, map::slippy::cache,
    map::slippy::fetcher, mapproj, math, math::bigfloat,
    math::bignum, math::calculus, math::calculus::symdiff,
    math::complexnumbers, math::constants, math::fourier,
    math::fuzzy, math::geometry, math::interpolate,
    math::machineparameters, math::numtheory, math::optimize,
    math::polynomials, math::rationalfunctions, math::roman,
    math::special, math::statistics, md4, md5, md5crypt, mime,
    nameserv, nameserv::auto, nameserv::common, nameserv::server,
    namespacex, ncgi, nmea, nntp, otp, page::analysis::peg::emodes,
    page::analysis::peg::minimize, page::analysis::peg::reachable,
    page::analysis::peg::realizable, page::compiler::peg::mecpu,
    page::config::peg, page::gen::peg::canon, page::gen::peg::cpkg,
    page::gen::peg::hb, page::gen::peg::me, page::gen::peg::mecpu,
    page::gen::peg::ser, page::gen::tree::text, page::parse::lemon,
    page::parse::peg, page::parse::peghb, page::parse::pegser,
    page::pluginmgr, page::reader::hb, page::reader::lemon,
    page::reader::peg, page::reader::ser, page::reader::treeser,
    page::transform::mecpu, page::transform::reachable,
    page::transform::realizable, page::util::flow,
    page::util::norm::lemon, page::util::norm::peg, page::util::peg,
    page::util::quote, page::writer::hb, page::writer::identity,
    page::writer::me, page::writer::mecpu, page::writer::null,
    page::writer::peg, page::writer::ser, page::writer::tpc,
    page::writer::tree, paths, picoirc, pluginmgr, png, pop3d::dbox,
    pop3d::udb, profiler, pt::ast, pt::parse::peg, pt::pe,
    pt::pe::op, pt::peg, pt::peg::container,
    pt::peg::container::peg, pt::peg::export,
    pt::peg::export::container, pt::peg::export::json,
    pt::peg::export::peg, pt::peg::from::json, pt::peg::from::peg,
    pt::peg::import, pt::peg::import::json, pt::peg::interp,
    pt::peg::op, pt::peg::to::container, pt::peg::to::cparam,
    pt::peg::to::json, pt::peg::to::param, pt::peg::to::peg,
    pt::peg::to::tclparam, pt::tclparam::configuration::snit, rc4,
    rcs, report, resolv, ripemd128, ripemd160, S3, SASL, SASL::NTLM,
    SASL::XGoogleToken, sha1, sha256, simulation::annealing,
    simulation::montecarlo, smtp, snit, soundex, spf, stooop,
    stringprep, stringprep::data, struct, struct::disjointset,
    struct::graph, struct::graph::op, struct::matrix, struct::pool,
    struct::prioqueue, struct::queue, struct::record, struct::set,
    struct::skiplist, struct::stack, struct::tree, sum, switched,
    tar, tcl::chan::core, tcl::chan::events, tcl::chan::fifo,
    tcl::chan::fifo2, tcl::chan::halfpipe, tcl::chan::null,
    tcl::chan::nullzero, tcl::chan::random, tcl::chan::textwindow,
    tcl::chan::zero, tcl::randomseed, tcl::transform::adler32,
    tcl::transform::base64, tcl::transform::core,
    tcl::transform::counter, tcl::transform::crc32,
    tcl::transform::hex, tcl::transform::identity,
    tcl::transform::limitsize, tcl::transform::observe,
    tcl::transform::otp, tcl::transform::rot,
    tcl::transform::spacer, tcl::transform::zlib, tclDES, tclDESjr,
    term, term::ansi::code, term::ansi::code::attr,
    term::ansi::code::ctrl, term::ansi::code::macros,
    term::ansi::send, term::interact::menu, term::interact::pager,
    term::receive, term::receive::bind, term::send, text::write,
    textutil, textutil::expander, textutil::repeat, textutil::split,
    textutil::string, textutil::tabify, textutil::trim, tie,
    tie::std::array, tie::std::dsource, tie::std::file,
    tie::std::growfile, tie::std::log, tie::std::rarray, tiff, time,
    transfer::connect, transfer::copy, transfer::copy::queue,
    transfer::data::destination, transfer::data::source,
    transfer::receiver, transfer::transmitter, treeql, uevent,
    uevent::onidle, unicode, unicode::data, units, uri::urn,
    uuencode, uuid, wip, xsxp, yencode

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
    
