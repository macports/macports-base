Overview
========

    7   new packages                in 5   modules
    33  changed packages            in 29  modules
    10  internally changed packages in 6   modules
    344 unchanged packages          in 90  modules
    400 packages, total             in 110 modules, total

New in tcllib 1.15
==================

    Module      Package                   New Version   Comments
    ----------- ------------------------- ------------- ----------
    clock       clock::iso8601            0.1
                clock::rfc2822            0.1
    ----------- ------------------------- ------------- ----------
    fileutil    fileutil::decode          0.1
    generator   generator                 0.1
    map         map::geocode::nominatim   0.1
    ----------- ------------------------- ------------- ----------
    zip         zipfile::decode           0.2
                zipfile::encode           0.1
    ----------- ------------------------- ------------- ----------

Changes from tcllib 1.14 to 1.15
================================

                                                tcllib 1.14   tcllib 1.15
    Module             Package                  Old Version   New Version   Comments
    ------------------ ------------------------ ------------- ------------- ----------
    aes                aes                      1.0.2         1.1           D EF
    crc                crc16                    1.1.1         1.1.2         B
    csv                csv                      0.7.3         0.8           EF
    doctools           doctools                 1.4.13        1.4.14        T B
    ------------------ ------------------------ ------------- ------------- ----------
    fileutil           fileutil                 1.14.4        1.14.5        B
                       fileutil::traverse       0.4.2         0.4.3         B
    ------------------ ------------------------ ------------- ------------- ----------
    grammar_peg        grammar::peg             0.1           0.2           B
    htmlparse          htmlparse                1.2           1.2.1         B
    http               autoproxy                1.5.1         1.5.3         B
    imap4              imap4                    0.3           0.4           EF
    inifile            inifile                  0.2.4         0.2.5         B
    json               json::write              1.0.1         1.0.2         B
    log                logger                   0.9           0.9.3         B
    ------------------ ------------------------ ------------- ------------- ----------
    map                map::slippy              0.4           0.5           EF
                       map::slippy::fetcher     0.2           0.3           EF
    ------------------ ------------------------ ------------- ------------- ----------
    math               math::statistics         0.7.0         0.8.0         EF
    mime               mime                     1.5.4         1.5.6         B
    ncgi               ncgi                     1.3.2         1.4.1         EF B T D
    ooutil             oo::util                 1             1.1           EF
    pki                pki                      0.2           0.6           EF
    png                png                      0.1.2         0.2           EF
    pop3               pop3                     1.8           1.9           B T
    simulation         simulation::random       0.3           0.3.1         B
    ------------------ ------------------------ ------------- ------------- ----------
    struct             struct::list             1.8.1         1.8.2         B T
                       struct::queue            1.4.2         1.4.4         B T D
                       struct::stack            1.5.1         1.5.3         B T
    ------------------ ------------------------ ------------- ------------- ----------
    tar                tar                      0.7           0.7.1         B
    tepam              tepam                    0.2.0         0.4.0         EF D T
    term               term::ansi::code::ctrl   0.1.1         0.1.2         B
    uev                uevent                   0.2           0.3.1         EF B
    uuid               uuid                     1.0.1         1.0.2         B
    valtype            valtype::iban            1             1.1           EF
    virtchannel_base   tcl::chan::cat           1.0.1         1.0.2         B
    ------------------ ------------------------ ------------- ------------- ----------

Invisible changes (documentation, testsuites)
=============================================

                                          tcllib 1.14   tcllib 1.15
    Module       Package                  Old Version   New Version   Comments
    ------------ ------------------------ ------------- ------------- ----------
    base64       base64                   2.4.2         2.4.2         D
    cmdline      cmdline                  1.3.3         1.3.3         T
    ------------ ------------------------ ------------- ------------- ----------
    grammar_me   grammar::me::cpu         0.2           0.2           T
                 grammar::me::cpu::core   0.2           0.2           T
                 grammar::me::cpu::gasm   0.1           0.1           T
                 grammar::me::tcl         0.1           0.1           T
                 grammar::me::util        0.1           0.1           T
    ------------ ------------------------ ------------- ------------- ----------
    irc          irc                      0.6.1         0.6.1         D
    ------------ ------------------------ ------------- ------------- ----------
    struct       struct::tree             1.2.2         1.2.2         D
                 struct::tree             2.1.2         2.1.2         D
    ------------ ------------------------ ------------- ------------- ----------
    try          try                      1             1             D
    ------------ ------------------------ ------------- ------------- ----------

Unchanged
=========

    ascii85, asn, base32, base32::core, base32::hex, bee, bench,
    bench::in, bench::out::csv, bench::out::text, bibtex, blowfish,
    cache::async, calendar, char, cksum, comm, configuration,
    control, coroutine, coroutine::auto, counter, crc32, des, dns,
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
    doctools::toc::structure, exif, fileutil::magic::cfront,
    fileutil::magic::cgen, fileutil::magic::filetype,
    fileutil::magic::mimetype, fileutil::magic::rt, fileutil::multi,
    fileutil::multi::op, ftp, ftp::geturl, ftpd, gpx,
    grammar::aycock, grammar::aycock::debug,
    grammar::aycock::runtime, grammar::fa, grammar::fa::dacceptor,
    grammar::fa::dexec, grammar::fa::op, grammar::peg::interp, hook,
    html, huddle, ident, interp, interp::delegate::method,
    interp::delegate::proc, ip, javascript, jpeg, json, lambda,
    ldap, ldapx, log, logger::appender, logger::utils,
    map::slippy::cache, mapproj, math, math::bigfloat, math::bignum,
    math::calculus, math::calculus::symdiff, math::complexnumbers,
    math::constants, math::decimal, math::fourier, math::fuzzy,
    math::geometry, math::interpolate, math::linearalgebra,
    math::machineparameters, math::numtheory, math::optimize,
    math::polynomials, math::rationalfunctions, math::roman,
    math::special, md4, md5, md5crypt, multiplexer, nameserv,
    nameserv::auto, nameserv::common, nameserv::server, namespacex,
    nmea, nntp, otp, page::analysis::peg::emodes,
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
    page::writer::tree, paths, picoirc, pluginmgr, pop3d,
    pop3d::dbox, pop3d::udb, profiler, pt::ast,
    pt::cparam::configuration::critcl, pt::parse::peg, pt::pe,
    pt::pe::op, pt::peg, pt::peg::container,
    pt::peg::container::peg, pt::peg::export,
    pt::peg::export::container, pt::peg::export::json,
    pt::peg::export::peg, pt::peg::from::json, pt::peg::from::peg,
    pt::peg::import, pt::peg::import::json, pt::peg::import::peg,
    pt::peg::interp, pt::peg::op, pt::peg::to::container,
    pt::peg::to::cparam, pt::peg::to::json, pt::peg::to::param,
    pt::peg::to::peg, pt::peg::to::tclparam, pt::pgen, pt::rde,
    pt::tclparam::configuration::snit,
    pt::tclparam::configuration::tcloo, rc4, rcs, report, resolv,
    rest, ripemd128, ripemd160, S3, SASL, SASL::NTLM,
    SASL::XGoogleToken, sha1, sha256, simulation::annealing,
    simulation::montecarlo, smtp, smtpd, snit, soundex, spf, stooop,
    stringprep, stringprep::data, struct, struct::disjointset,
    struct::graph, struct::graph::op, struct::matrix, struct::pool,
    struct::prioqueue, struct::record, struct::set,
    struct::skiplist, sum, switched, tcl::chan::core,
    tcl::chan::events, tcl::chan::facade, tcl::chan::fifo,
    tcl::chan::fifo2, tcl::chan::halfpipe, tcl::chan::memchan,
    tcl::chan::null, tcl::chan::nullzero, tcl::chan::random,
    tcl::chan::std, tcl::chan::string, tcl::chan::textwindow,
    tcl::chan::variable, tcl::chan::zero, tcl::randomseed,
    tcl::transform::adler32, tcl::transform::base64,
    tcl::transform::core, tcl::transform::counter,
    tcl::transform::crc32, tcl::transform::hex,
    tcl::transform::identity, tcl::transform::limitsize,
    tcl::transform::observe, tcl::transform::otp,
    tcl::transform::rot, tcl::transform::spacer,
    tcl::transform::zlib, tclDES, tclDESjr, term, term::ansi::code,
    term::ansi::code::attr, term::ansi::code::macros,
    term::ansi::ctrl::unix, term::ansi::send, term::interact::menu,
    term::interact::pager, term::receive, term::receive::bind,
    term::send, text::write, textutil, textutil::adjust,
    textutil::expander, textutil::repeat, textutil::split,
    textutil::string, textutil::tabify, textutil::trim, tie,
    tie::std::array, tie::std::dsource, tie::std::file,
    tie::std::growfile, tie::std::log, tie::std::rarray, tiff, time,
    transfer::connect, transfer::copy, transfer::copy::queue,
    transfer::data::destination, transfer::data::source,
    transfer::receiver, transfer::transmitter, treeql,
    uevent::onidle, unicode, unicode::data, units, uri, uri::urn,
    uuencode, valtype::common, valtype::creditcard::amex,
    valtype::creditcard::discover, valtype::creditcard::mastercard,
    valtype::creditcard::visa, valtype::gs1::ean13, valtype::imei,
    valtype::isbn, valtype::luhn, valtype::luhn5, valtype::usnpi,
    valtype::verhoeff, wip, xsxp, yaml, yencode

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
    
