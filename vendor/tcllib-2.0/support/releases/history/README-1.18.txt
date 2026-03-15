Overview
========

    18  new packages                in 14  modules
    32  changed packages            in 22  modules
    24  internally changed packages in 18  modules
    357 unchanged packages          in 97  modules
    438 packages, total             in 126 modules, total

New in tcllib 1.18
==================

    Module          Package             New Version   Comments
    --------------- ------------------- ------------- ----------
    dicttool        dicttool            1.0
    --------------- ------------------- ------------- ----------
    httpd           httpd               4.0
                    httpd::content      4.0
                    httpd::dispatch     4.0
                    scgi::app           0.1
    --------------- ------------------- ------------- ----------
    httpwget        http::wget          0.1
    markdown        Markdown            1.0
    math            math::exact         1.0
    nns             nameserv::cluster   0.2.3
    oodialect       oo::dialect         0.3
    --------------- ------------------- ------------- ----------
    oometa          oo::meta            0.4.1
                    oo::option          0.3
    --------------- ------------------- ------------- ----------
    processman      processman          0.3
    tool            tool                0.5
    tool_datatype   tool::datatype      0.1
    try             throw               1
    yaml            huddle::json        0.1
    zip             zipfile::mkzip      1.2
    --------------- ------------------- ------------- ----------

Changes from tcllib 1.17 to 1.18
================================

                                          tcllib 1.17   tcllib 1.18
    Module      Package                   Old Version   New Version   Comments
    ----------- ------------------------- ------------- ------------- ----------
    cron        cron                      1.1           1.2.1         B EF
    csv         csv                       0.8           0.8.1         B
    ----------- ------------------------- ------------- ------------- ----------
    debug       debug                     1.0.5         1.0.6         B D EF
                debug::caller             1             1.1           EF
    ----------- ------------------------- ------------- ------------- ----------
    docstrip    docstrip::util            1.3           1.3.1         B D
    dtplite     dtplite                   1.2           1.3           B EF
    ----------- ------------------------- ------------- ------------- ----------
    fileutil    fileutil                  1.14.10       1.15          B D EF T
                fileutil::traverse        0.5           0.6           B D T
    ----------- ------------------------- ------------- ------------- ----------
    ftp         ftp::geturl               0.2.1         0.2.2         B
    ftpd        ftpd                      1.2.6         1.3           B EF
    htmlparse   htmlparse                 1.2.1         1.2.2         D EF T
    imap4       imap4                     0.5.2         0.5.3         D EF
    irc         picoirc                   0.5.1         0.5.2         B D
    map         map::slippy::fetcher      0.3           0.4           D EF
    ----------- ------------------------- ------------- ------------- ----------
    math        math::calculus::symdiff   1.0           1.0.1         B T
                math::constants           1.0.1         1.0.2         B D
                math::statistics          0.9.3                       B EF
                math::statistics                        1.0           B EF
    ----------- ------------------------- ------------- ------------- ----------
    nettool     nettool                   0.4           0.5.1         B EF I
    ooutil      oo::util                  1.2.1         1.2.2         B D T
    ----------- ------------------------- ------------- ------------- ----------
    pt          pt::pe::op                1             1.0.1         B D T
                pt::peg::to::tclparam     1.0.2         1.0.3         B D T
                pt::rde                   1.0.3         1.1           B D I T
                pt::rde::oo               1.0.3         1.1           D I
                pt::util                  1             1.1           B
    ----------- ------------------------- ------------- ------------- ----------
    rest        rest                      1.0.1         1.0.2         B D
    tie         tie::std::rarray          1.0           1.0.1         B D T
    uri         uri                       1.2.5         1.2.6         D EF T
    uuid        uuid                      1.0.4         1.0.5         B I
    ----------- ------------------------- ------------- ------------- ----------
    yaml        huddle                    0.1.5         0.2           D I T
                yaml                      0.3.7         0.3.9         D I T
    ----------- ------------------------- ------------- ------------- ----------
    zip         zipfile::decode           0.6.1         0.7           EF I
                zipfile::encode           0.3           0.4           B D
    ----------- ------------------------- ------------- ------------- ----------

Invisible changes (documentation, testsuites)
=============================================

                                       tcllib 1.17   tcllib 1.18
    Module        Package              Old Version   New Version   Comments
    ------------- -------------------- ------------- ------------- ----------
    base64        uuencode             1.1.5         1.1.5         I
                  yencode              1.1.3         1.1.3         I
    ------------- -------------------- ------------- ------------- ----------
    crc           crc32                1.3.2         1.3.2         I
                  sum                  1.1.2         1.1.2         I
    ------------- -------------------- ------------- ------------- ----------
    dns           spf                  1.1.1         1.1.1         I
    docstrip      docstrip             1.2           1.2           D
    ------------- -------------------- ------------- ------------- ----------
    doctools      doctools             1.4.19        1.4.19        EF
                  doctools::idx        1.0.5         1.0.5         EF
                  doctools::idx        2             2             EF
                  doctools::toc        1.1.4         1.1.4         EF
                  doctools::toc        2             2             EF
    ------------- -------------------- ------------- ------------- ----------
    gpx           gpx                  1             1             T
    json          json                 1.3.3         1.3.3         B
    ldap          ldapx                1.0           1.0           D
    math          math::special        0.3.0         0.3.0         D
    md4           md4                  1.0.6         1.0.6         I
    ------------- -------------------- ------------- ------------- ----------
    md5           md5                  1.4.4         1.4.4         I
                  md5                  2.0.7         2.0.7         I
    ------------- -------------------- ------------- ------------- ----------
    multiplexer   multiplexer          0.2           0.2           T
    nns           nameserv::auto       0.3           0.3           D
    processman    odie::processman     0.3           0.3           B I
    rc4           rc4                  1.1.0         1.1.0         T
    ------------- -------------------- ------------- ------------- ----------
    ripemd        ripemd128            1.0.5         1.0.5         I
                  ripemd160            1.0.5         1.0.5         I
    ------------- -------------------- ------------- ------------- ----------
    sha1          sha1                 1.1.1         1.1.1         I
                  sha1                 2.0.3         2.0.3         I
                  sha256               1.0.3         1.0.3         I
    ------------- -------------------- ------------- ------------- ----------
    textutil      textutil::expander   1.3.1         1.3.1         I
    ------------- -------------------- ------------- ------------- ----------

Unchanged
=========

    aes, ascii85, asn, autoproxy, base32, base32::core, base32::hex,
    base64, bee, bench, bench::in, bench::out::csv,
    bench::out::text, bibtex, blowfish, cache::async, calendar,
    char, cksum, clock::iso8601, clock::rfc2822, cmdline, comm,
    configuration, control, coroutine, coroutine::auto, counter,
    crc16, debug::heartbeat, debug::timestamp, des, dns,
    doctools::changelog, doctools::config, doctools::cvs,
    doctools::html, doctools::html::cssdefaults, doctools::idx,
    doctools::idx::export, doctools::idx::export::docidx,
    doctools::idx::export::html, doctools::idx::export::json,
    doctools::idx::export::nroff, doctools::idx::export::text,
    doctools::idx::export::wiki, doctools::idx::import,
    doctools::idx::import::docidx, doctools::idx::import::json,
    doctools::idx::parse, doctools::idx::structure,
    doctools::msgcat, doctools::msgcat::idx::c,
    doctools::msgcat::idx::de, doctools::msgcat::idx::en,
    doctools::msgcat::idx::fr, doctools::msgcat::toc::c,
    doctools::msgcat::toc::de, doctools::msgcat::toc::en,
    doctools::msgcat::toc::fr, doctools::nroff::man_macros,
    doctools::paths, doctools::tcl::parse, doctools::text,
    doctools::toc, doctools::toc::export,
    doctools::toc::export::doctoc, doctools::toc::export::html,
    doctools::toc::export::json, doctools::toc::export::nroff,
    doctools::toc::export::text, doctools::toc::export::wiki,
    doctools::toc::import, doctools::toc::import::doctoc,
    doctools::toc::import::json, doctools::toc::parse,
    doctools::toc::structure, exif, fileutil::decode,
    fileutil::magic::cfront, fileutil::magic::cgen,
    fileutil::magic::filetype, fileutil::magic::mimetype,
    fileutil::magic::rt, fileutil::multi, fileutil::multi::op, ftp,
    generator, grammar::aycock, grammar::aycock::debug,
    grammar::aycock::runtime, grammar::fa, grammar::fa::dacceptor,
    grammar::fa::dexec, grammar::fa::op, grammar::me::cpu,
    grammar::me::cpu::core, grammar::me::cpu::gasm,
    grammar::me::tcl, grammar::me::util, grammar::peg,
    grammar::peg::interp, hook, html, ident, inifile, interp,
    interp::delegate::method, interp::delegate::proc, ip, irc,
    javascript, jpeg, json::write, lambda, ldap, log, logger,
    logger::appender, logger::utils, map::geocode::nominatim,
    map::slippy, map::slippy::cache, mapproj, math, math::bigfloat,
    math::bignum, math::calculus, math::complexnumbers,
    math::decimal, math::fourier, math::fuzzy, math::geometry,
    math::interpolate, math::linearalgebra, math::machineparameters,
    math::numtheory, math::optimize, math::polynomials,
    math::rationalfunctions, math::roman, md5crypt, mime, nameserv,
    nameserv::common, nameserv::server, namespacex, ncgi, nmea,
    nntp, oauth, otp, page::analysis::peg::emodes,
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
    page::writer::tree, paths, pki, pluginmgr, png, pop3, pop3d,
    pop3d::dbox, pop3d::udb, profiler, pt::ast,
    pt::cparam::configuration::critcl,
    pt::cparam::configuration::tea, pt::parse::peg, pt::pe, pt::peg,
    pt::peg::container, pt::peg::container::peg, pt::peg::export,
    pt::peg::export::container, pt::peg::export::json,
    pt::peg::export::peg, pt::peg::from::json, pt::peg::from::peg,
    pt::peg::import, pt::peg::import::json, pt::peg::import::peg,
    pt::peg::interp, pt::peg::op, pt::peg::to::container,
    pt::peg::to::cparam, pt::peg::to::json, pt::peg::to::param,
    pt::peg::to::peg, pt::pgen, pt::tclparam::configuration::snit,
    pt::tclparam::configuration::tcloo, rcs, report, resolv, S3,
    SASL, SASL::NTLM, SASL::SCRAM, SASL::XGoogleToken,
    simulation::annealing, simulation::montecarlo,
    simulation::random, smtp, smtpd, snit, soundex, stooop,
    string::token, string::token::shell, stringprep,
    stringprep::data, struct, struct::disjointset, struct::graph,
    struct::graph::op, struct::list, struct::matrix, struct::pool,
    struct::prioqueue, struct::queue, struct::record, struct::set,
    struct::skiplist, struct::stack, struct::tree, switched, tar,
    tcl::chan::cat, tcl::chan::core, tcl::chan::events,
    tcl::chan::facade, tcl::chan::fifo, tcl::chan::fifo2,
    tcl::chan::halfpipe, tcl::chan::memchan, tcl::chan::null,
    tcl::chan::nullzero, tcl::chan::random, tcl::chan::std,
    tcl::chan::string, tcl::chan::textwindow, tcl::chan::variable,
    tcl::chan::zero, tcl::randomseed, tcl::transform::adler32,
    tcl::transform::base64, tcl::transform::core,
    tcl::transform::counter, tcl::transform::crc32,
    tcl::transform::hex, tcl::transform::identity,
    tcl::transform::limitsize, tcl::transform::observe,
    tcl::transform::otp, tcl::transform::rot,
    tcl::transform::spacer, tcl::transform::zlib, tclDES, tclDESjr,
    tepam, tepam::doc_gen, term, term::ansi::code,
    term::ansi::code::attr, term::ansi::code::ctrl,
    term::ansi::code::macros, term::ansi::ctrl::unix,
    term::ansi::send, term::interact::menu, term::interact::pager,
    term::receive, term::receive::bind, term::send, text::write,
    textutil, textutil::adjust, textutil::repeat, textutil::split,
    textutil::string, textutil::tabify, textutil::trim, tie,
    tie::std::array, tie::std::dsource, tie::std::file,
    tie::std::growfile, tie::std::log, tiff, time,
    transfer::connect, transfer::copy, transfer::copy::queue,
    transfer::data::destination, transfer::data::source,
    transfer::receiver, transfer::transmitter, treeql, try, uevent,
    uevent::onidle, unicode, unicode::data, units, uri::urn,
    valtype::common, valtype::creditcard::amex,
    valtype::creditcard::discover, valtype::creditcard::mastercard,
    valtype::creditcard::visa, valtype::gs1::ean13, valtype::iban,
    valtype::imei, valtype::isbn, valtype::luhn, valtype::luhn5,
    valtype::usnpi, valtype::verhoeff, websocket, wip, xsxp

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
    
