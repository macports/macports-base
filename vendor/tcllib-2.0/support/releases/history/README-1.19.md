Overview
========

||||||
|---|---|---|---|---|
|7|new packages|in|6|modules|
|52|changed packages|in|35|modules|
|15|internally changed packages|in|10|modules|
|359|unchanged packages|in|105|modules|
|443|packages, total|in|130|modules, total|

Legend
======

|Change|Details|Comments|
|---|---|---|
|Major|API|__incompatible__ API changes|
|Minor|EF|Extended functionality, API|
||I|Major rewrite, but no API change|
|Patch|B|Bug fixes|
||EX|New examples|
||P|Performance enhancement|
|None|T|Testsuite changes|
||D|Documentation updates|

New in Tcllib 1.19
==================

|Module|Package|New Version|Comments|
|---|---|---|---|
|defer|defer|1||
|math|math::PCA|1.0||
|practcl|practcl|0.11||
|||||
|pt|pt::rde::nx|1.1.1.1||
||pt::tclparam::configuration::nx|1.0.1||
|||||
|tool-ui|tool-ui|0.2.1||
|udpcluster|udpcluster|0.3.3||

Changes from Tcllib 1.18 to 1.19
================================

|Module|Package|From 1.18|To 1.19|Comments|
|---|---|---|---|---|
|coroutine|coroutine|1.1.3|1.2|B D EF|
|crc|crc16|1.1.2|1.1.3|B D|
|cron|cron|1.2.1|2.1|API B D EF T|
|dicttool|dicttool|1.0|1.1|D EF|
||||||
|dns|dns|1.3.5|1.4.0|D EF T|
||ip|1.3|1.4|B D T|
||||||
|doctools|doctools|1.4.19|1.4.21|B D T|
||doctools::idx|1.0.5|1.0.7|B D T|
||doctools::toc|1.1.4|1.1.6|B D T|
||||||
|doctools2idx|doctools::idx::export|0.1|0.2|B|
||doctools::idx::import|0.1|0.2|B|
||||||
|doctools2toc|doctools::toc::export|0.1|0.2|B|
||doctools::toc::import|0.1|0.2|B|
||||||
|fileutil|fileutil|1.15|1.16|B T|
||fileutil::decode|0.2|0.2.1|B|
||||||
|fumagic|fileutil::magic::cfront|1.0|1.2.0|B D EF T|
||fileutil::magic::cgen|1.0|1.2.0|D EF T|
||fileutil::magic::filetype|1.0.2|2.0|API D EF T|
||fileutil::magic::rt|1.0|2.0|API D EF T|
||||||
|http|autoproxy|1.5.3|1.6|D EF T|
||||||
|httpd|httpd|4.0|4.1.1|B EF I T|
||httpd::content|4.0||Removed|
||scgi::app|0.1||Removed|
||||||
|inifile|ini|0.3|0.3.1|B D|
|json|json|1.3.3|1.3.4|B D T|
||||||
|ldap|ldap|1.8|1.9.2|B D T|
||ldapx|1.0|1.1|B D T|
||||||
|markdown|Markdown|1.0|1.1|D EF T|
||||||
|math|math::calculus|0.8.1|0.8.2|B T|
||math::exact|1.0|1.0.1|B D T|
||math::geometry|1.1.3|1.2.3|B D EF I T|
||math::interpolate|1.1|1.1.1|B T|
||math::linearalgebra|1.1.5|1.1.6|B T|
||math::numtheory|1.0|1.1|D EF T|
||math::statistics|1.0|1.1.1|B D EF T|
||||||
|md4|md4|1.0.6|1.0.7|B D|
|nettool|nettool|0.5.1|0.5.2|B I|
|oauth|oauth|1|1.0.1|B D|
|oodialect|oo::dialect|0.3|0.3.3|B I T|
||||||
|oometa|oo::meta|0.4.1|0.7.1|B EF T|
||oo::option|0.3|0.3.1|B|
||||||
|pki|pki|0.6|0.10|B D EF T|
||||||
|processman|odie::processman|0.3|0.5|EF|
||processman|0.3|0.5|B EF|
||||||
|pt|pt::pgen|1.0.3|1.1|EF|
|rest|rest|1.0.2|1.3.1|D EF I|
||||||
|struct|struct::graph|1.2.1|1.2.1|B D T|
||struct::graph|2.4|2.4.1|B D T|
||||||
|tar|tar|0.10|0.11|B D T|
|tepam|tepam|0.5|0.5.2|B D T|
|textutil|textutil::split|0.7|0.8|B D T|
|tool|tool|0.5|0.7|B D EF T|
|units|units|2.1.1|2.2.1|B EF T|
|uri|uri|1.2.6|1.2.7|B D T|
|uuid|uuid|1.0.5|1.0.6|B|
|valtype|valtype::iban|1.5|1.7|D EF T|
||||||
|virtchannel_base|tcl::chan::memchan|1.0.3|1.0.4|B D T|
||tcl::chan::string|1.0.2|1.0.3|B D T|
||tcl::chan::variable|1.0.3|1.0.4|B D T|
||||||
|websocket|websocket|1.4|1.4.1|B|
||||||
|yaml|huddle|0.2|0.3|B D T|
||yaml|0.3.9|0.4.1|B D EF T|
|zip|zipfile::decode|0.7|0.7.1|D T|

Invisible changes (documentation, testsuites)
=============================================

|Module|Package|From 1.18|To 1.19|Comments|
|---|---|---|---|---|
|bee|bee|0.1|0.1|D|
|comm|comm|4.6.3.1|4.6.3.1|T|
||||||
|des|tclDES|1.0.0|1.0.0|D|
||tclDESjr|1.0.0|1.0.0|D|
||||||
|docstrip|docstrip::util|1.3.1|1.3.1|D|
|doctools2idx|doctools::idx|2|2|---|
|doctools2toc|doctools::toc|2|2|---|
||||||
|math|math::bigfloat|1.2.2|1.2.2|T|
||math::bigfloat|2.0.2|2.0.2|T|
||math::decimal|1.0.3|1.0.3|D T|
||math::special|0.3.0|0.3.0|T|
||||||
|md5|md5|1.4.4|1.4.4|T|
||md5|2.0.7|2.0.7|T|
||||||
|pop3|pop3|1.9|1.9|T|
|pt|pt::rde::oo|1.1|1.1|I|
||||||
|try|throw|1|1|D|
||try|1|1|D|
|virtchannel_base|tcl::chan::fifo|1|1|D|
||tcl::chan::fifo2|1|1|D|

Unchanged
=========

    aes, ascii85, asn, base32, base32::core, base32::hex, base64,
    bench, bench::in, bench::out::csv, bench::out::text, bibtex,
    blowfish, cache::async, calendar, char, cksum, clock::iso8601,
    clock::rfc2822, cmdline, configuration, control,
    coroutine::auto, counter, crc32, csv, debug, debug::caller,
    debug::heartbeat, debug::timestamp, des, docstrip,
    doctools::changelog, doctools::config, doctools::cvs,
    doctools::html, doctools::html::cssdefaults,
    doctools::idx::export::docidx,
    doctools::idx::export::html, doctools::idx::export::json,
    doctools::idx::export::nroff, doctools::idx::export::text,
    doctools::idx::export::wiki, 
    doctools::idx::import::docidx, doctools::idx::import::json,
    doctools::idx::parse, doctools::idx::structure,
    doctools::msgcat, doctools::msgcat::idx::c,
    doctools::msgcat::idx::de, doctools::msgcat::idx::en,
    doctools::msgcat::idx::fr, doctools::msgcat::toc::c,
    doctools::msgcat::toc::de, doctools::msgcat::toc::en,
    doctools::msgcat::toc::fr, doctools::nroff::man_macros,
    doctools::paths, doctools::tcl::parse, doctools::text,
    doctools::toc::export::doctoc,
    doctools::toc::export::html, doctools::toc::export::json,
    doctools::toc::export::nroff, doctools::toc::export::text,
    doctools::toc::export::wiki, 
    doctools::toc::import::doctoc, doctools::toc::import::json,
    doctools::toc::parse, doctools::toc::structure, dtplite, exif,
    fileutil::multi, fileutil::multi::op, fileutil::traverse, ftp,
    ftp::geturl, ftpd, generator, gpx, grammar::aycock,
    grammar::aycock::debug, grammar::aycock::runtime, grammar::fa,
    grammar::fa::dacceptor, grammar::fa::dexec, grammar::fa::op,
    grammar::me::cpu, grammar::me::cpu::core,
    grammar::me::cpu::gasm, grammar::me::tcl, grammar::me::util,
    grammar::peg, grammar::peg::interp, hook, html, htmlparse,
    http::wget, http::wget, huddle::json, ident, imap4,
    interp, interp::delegate::method, interp::delegate::proc, irc,
    javascript, jpeg, json::write, lambda, log, logger,
    logger::appender, logger::utils, map::geocode::nominatim,
    map::slippy, map::slippy::cache, map::slippy::fetcher, mapproj,
    math, math::bignum, math::calculus::symdiff,
    math::complexnumbers, math::constants,
    math::fourier, math::fuzzy, math::machineparameters,
    math::optimize, math::polynomials, math::rationalfunctions,
    math::roman, md5crypt, mime, multiplexer, nameserv,
    nameserv::auto, nameserv::common, nameserv::server, namespacex,
    ncgi, nmea, nntp, oo::util, otp,
    page::analysis::peg::emodes, page::analysis::peg::minimize,
    page::analysis::peg::reachable, page::analysis::peg::realizable,
    page::compiler::peg::mecpu, page::config::peg,
    page::gen::peg::canon, page::gen::peg::cpkg, page::gen::peg::hb,
    page::gen::peg::me, page::gen::peg::mecpu, page::gen::peg::ser,
    page::gen::tree::text, page::parse::lemon, page::parse::peg,
    page::parse::peghb, page::parse::pegser, page::pluginmgr,
    page::reader::hb, page::reader::lemon, page::reader::peg,
    page::reader::ser, page::reader::treeser,
    page::transform::mecpu, page::transform::reachable,
    page::transform::realizable, page::util::flow,
    page::util::norm::lemon, page::util::norm::peg, page::util::peg,
    page::util::quote, page::writer::hb, page::writer::identity,
    page::writer::me, page::writer::mecpu, page::writer::null,
    page::writer::peg, page::writer::ser, page::writer::tpc,
    page::writer::tree, paths, picoirc, pluginmgr, png, pop3d,
    pop3d::dbox, pop3d::udb, profiler, pt::ast,
    pt::cparam::configuration::critcl,
    pt::cparam::configuration::tea, pt::parse::peg, pt::pe,
    pt::pe::op, pt::peg, pt::peg::container,
    pt::peg::container::peg, pt::peg::export,
    pt::peg::export::container, pt::peg::export::json,
    pt::peg::export::peg, pt::peg::from::json, pt::peg::from::peg,
    pt::peg::import, pt::peg::import::json, pt::peg::import::peg,
    pt::peg::interp, pt::peg::op, pt::peg::to::container,
    pt::peg::to::cparam, pt::peg::to::json, pt::peg::to::param,
    pt::peg::to::peg, pt::peg::to::tclparam, pt::rde,
    pt::tclparam::configuration::snit,
    pt::tclparam::configuration::tcloo, pt::util, rc4, rcs, report,
    resolv, ripemd128, ripemd160, S3, SASL, SASL::NTLM, SASL::SCRAM,
    SASL::XGoogleToken, sha1, sha256, simulation::annealing,
    simulation::montecarlo, simulation::random, smtp, smtpd, snit,
    soundex, spf, stooop, string::token, string::token::shell,
    stringprep, stringprep::data, struct, struct::disjointset,
    struct::graph::op, struct::list, struct::matrix, struct::pool,
    struct::prioqueue, struct::queue, struct::record, struct::set,
    struct::skiplist, struct::stack, struct::tree, sum, switched,
    tcl::chan::cat, tcl::chan::core, tcl::chan::events,
    tcl::chan::facade, tcl::chan::halfpipe, tcl::chan::null,
    tcl::chan::nullzero, tcl::chan::random, tcl::chan::std,
    tcl::chan::textwindow, tcl::chan::zero, tcl::randomseed,
    tcl::transform::adler32, tcl::transform::base64,
    tcl::transform::core, tcl::transform::counter,
    tcl::transform::crc32, tcl::transform::hex,
    tcl::transform::identity, tcl::transform::limitsize,
    tcl::transform::observe, tcl::transform::otp,
    tcl::transform::rot, tcl::transform::spacer,
    tcl::transform::zlib, tepam::doc_gen, term, term::ansi::code,
    term::ansi::code::attr, term::ansi::code::ctrl,
    term::ansi::code::macros, term::ansi::ctrl::unix,
    term::ansi::send, term::interact::menu, term::interact::pager,
    term::receive, term::receive::bind, term::send, text::write,
    textutil, textutil::adjust, textutil::expander,
    textutil::repeat, textutil::string, textutil::tabify,
    textutil::trim, tie, tie::std::array, tie::std::dsource,
    tie::std::file, tie::std::growfile, tie::std::log,
    tie::std::rarray, tiff, time, tool::datatype, transfer::connect,
    transfer::copy, transfer::copy::queue,
    transfer::data::destination, transfer::data::source,
    transfer::receiver, transfer::transmitter, treeql, uevent,
    uevent::onidle, unicode, unicode::data, uri::urn, uuencode,
    valtype::common, valtype::creditcard::amex,
    valtype::creditcard::discover, valtype::creditcard::mastercard,
    valtype::creditcard::visa, valtype::gs1::ean13, valtype::imei,
    valtype::isbn, valtype::luhn, valtype::luhn5, valtype::usnpi,
    valtype::verhoeff, wip, xsxp, yencode, zipfile::encode,
    zipfile::mkzip
