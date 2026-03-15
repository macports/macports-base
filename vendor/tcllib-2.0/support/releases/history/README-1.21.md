Overview
========

||||||
|---:|:---|:---|---:|:---|
|7|new packages|in|3|modules|
|53|changed packages|in|34|modules|
|78|internally changed packages|in|19|modules|
|307|unchanged packages|in|102|modules|
|453|packages, total|in|132|modules, total|

Legend
======

|Change|Details|Comments|
|:---|:---|:---|
|Major|API|__incompatible__ API changes|
|Minor|EF|Extended functionality, API|
||I|Major rewrite, but no API change|
|Patch|B|Bug fixes|
||EX|New examples|
||P|Performance enhancement|
|None|T|Testsuite changes|
||D|Documentation updates|

New in Tcllib 1.21
==================

|Module|Package|New Version|Comments|
|:---|:---|:---|:---|
|math|math::changepoint|0.1||
||math::combinatorics|2.0||
||math::figurate|1.0||
||math::filters|0.1||
||math::probopt|1.0||
|mkdoc|mkdoc|0.7.0||
|struct|struct::list::test|1.8.4||
|||||

Deprecations in Tcllib 1.21
===========================

Four packages are stage 2 deprecated in favor of two replacements.
All internal users of the deprecated packages have been rewritten to
use their replacements.

|Module|Package|Replacement|Deprecation stage|
|---|---|---|---|
|doctools|doctools::paths|fileutil::paths|(D2) Attempts to use throw errors|
|doctools|doctools::config|struct::map|(D2) Attempts to use throw errors|
|pt|paths|fileutil::paths|(D2) Attempts to use throw errors|
|pt|configuration|struct::map|(D2) Attempts to use throw errors|

Stage 1 (__D1__) means that:

  - The deprecated packages still exist.
  - Their implementations have changed and throw errors.

Future progress:

  - In the release after 1.21 the stage 2 deprecated packages will be
    moved to stage 3 (__D3__). In that stage the implementations will
    be removed from Tcllib, causing `package require` to fail.

Changes from Tcllib 1.20 to 1.21
================================

|Module|Package|From 1.20|To 1.21|Comments|
|:---|:---|:---|:---|:---|
|base64|base64|2.4.2|2.5|B D EF T|
|bibtex|bibtex|0.6|0.7|D EF T|
|cmdline|cmdline|1.5|1.5.2|B D T|
|comm|comm|4.6.3.1|4.7|B I T|
||||||
|coroutine|coroutine|1.2|1.3|B D I|
||coroutine::auto|1.1.3|1.2|D I|
||||||
|crc|crc16|1.1.3|1.1.4|B D|
||crc32|1.3.2|1.3.3|B D|
||||||
|dns|dns|1.4.1|1.5.0|D EF|
|fileutil|fileutil|1.16|1.16.1|B T|
||||||
|fumagic|fileutil::magic::cfront|1.2.0|1.3.0|B|
||fileutil::magic::cgen|1.2.0|1.3.0|B|
||fileutil::magic::filetype|2.0|2.0.1|B|
||fileutil::magic::rt|2.0||B|
||fileutil::magic::rt||3.0|B|
||||||
|generator|generator|0.1|0.2|B D|
|hook|hook|0.1|0.2|B D T|
|httpd|httpd|4.3.4|4.3.5|B T|
|inifile|inifile|0.3.1|0.3.2|B T|
||||||
|irc|irc|0.6.2|0.7.0|I|
||picoirc|0.5.2|0.13.0|B D EF I T|
||||||
|json|json::write|1.0.3|1.0.4|EF|
||||||
|ldap|ldap|1.9.2|1.10.1|B D|
||ldapx|1.1|1.2|EF|
||||||
|markdown|Markdown|1.1.1|1.2.2|B D EF T|
||||||
|math|math::bigfloat|1.2.2|1.2.3|B D T|
||math::bigfloat|2.0.2|2.0.3|B D T|
||math::decimal|1.0.3|1.0.4|B T|
||math::geometry|1.3.1|1.4.1|B D EF T|
||math::numtheory|1.1.1|1.1.3|B D EF T|
||math::special|0.4.0|0.5.2|D EF I T|
||||||
|md5|md5|1.4.4|1.4.5|D I P|
||md5|2.0.7|2.0.8|D I P|
||||||
|mime|mime|1.6.2|1.7.0|B D EF I T|
||smtp|1.5|1.5.1|B D T|
||||||
|namespacex|namespacex|0.2|0.3|B D T|
|pki|pki|0.10|0.20|B D EF I T|
|pop3|pop3|1.9|1.10|D EF T|
||||||
|processman|odie::processman|0.5|0.6|B D|
||processman|0.5|0.6|B D|
||||||
|profiler|profiler|0.4|0.6|B D T|
|pt|char|1.0.1|1.0.2|B T|
|rest|rest|1.3.1|1.5|D EF|
|struct|struct::list|1.8.4|1.8.5|B D T|
|term|term::ansi::code::ctrl|0.2|0.3|B D|
||||||
|tie|tie|1.1|1.2|D EF T|
||tie::std::array|1.0|1.1|D EF T|
||tie::std::dsource|1.0|1.1|D EF T|
||tie::std::file|1.0.4|1.1|D EF T|
||tie::std::growfile|1.0|1.1|D EF T|
||tie::std::log|1.0|1.1|D EF T|
||tie::std::rarray|1.0.1|1.1|D EF T|
|virtchannel_base|tcl::chan::halfpipe|1.0.1|1.0.2|EF|
|websocket|websocket|1.4.1|1.4.2|B|
|yaml|huddle|0.3|0.4|B D T|
|zip|zipfile::decode|0.7.1|0.9|B D EF|
||||||

Invisible changes (documentation, testsuites)
=============================================

|Module|Package|From 1.20|To 1.21|Comments|
|:---|:---|:---|:---|:---|
|amazon-s3|S3|1.0.3|1.0.3|T|
|asn|asn|0.8.4|0.8.4|T|
|base64|yencode|1.1.3|1.1.3|T|
|clay|clay|0.8.6|0.8.6|T|
||||||
|clock|clock::iso8601|0.1|0.1|D|
||clock::rfc2822|0.1|0.1|D I|
||||||
|doctools2base|doctools::tcl::parse|0.1|0.1|T|
||||||
|doctools2idx|doctools::idx::export|0.2.1|0.2.1|T|
||doctools::idx::export::docidx|0.1|0.1|T|
||doctools::idx::export::html|0.2|0.2|T|
||doctools::idx::export::json|0.1|0.1|T|
||doctools::idx::export::nroff|0.3|0.3|T|
||doctools::idx::export::text|0.2|0.2|T|
||doctools::idx::export::wiki|0.2|0.2|T|
||doctools::idx::import|0.2.1|0.2.1|T|
||doctools::idx::import::docidx|0.1|0.1|T|
||doctools::idx::import::json|0.1|0.1|T|
||doctools::idx::parse|0.1|0.1|T|
||doctools::idx::structure|0.1|0.1|T|
||||||
|doctools2toc|doctools::toc::export|0.2.1|0.2.1|T|
||doctools::toc::export::doctoc|0.1|0.1|T|
||doctools::toc::export::html|0.1|0.1|T|
||doctools::toc::export::json|0.1|0.1|T|
||doctools::toc::export::nroff|0.2|0.2|T|
||doctools::toc::export::text|0.1|0.1|T|
||doctools::toc::export::wiki|0.1|0.1|T|
||doctools::toc::import|0.2.1|0.2.1|T|
||doctools::toc::import::doctoc|0.1|0.1|T|
||doctools::toc::import::json|0.1|0.1|T|
||doctools::toc::parse|0.1|0.1|T|
||doctools::toc::structure|0.1|0.1|T|
||||||
|grammar_fa|grammar::fa|0.5|0.5|T|
|httpwget|http::wget|0.1|0.1|I|
|mapproj|mapproj|1.0|1.0|I|
||||||
|math|math::fourier|1.0.2|1.0.2|D|
||math::machineparameters|0.1|0.1|D|
||math::quasirandom|1.0|1.0|D|
||||||
|oometa|oo::meta|0.7.1|0.7.1|T|
||||||
|pt|pt::ast|1.1|1.1|T|
||pt::cparam::configuration::critcl|1.0.2|1.0.2|I T|
||pt::cparam::configuration::tea|0.1|0.1|T|
||pt::parse::peg|1.0.1|1.0.1|I T|
||pt::pe|1.0.2|1.0.2|T|
||pt::pe::op|1.0.1|1.0.1|T|
||pt::peg|1|1|T|
||pt::peg::container|1|1|T|
||pt::peg::export|1.0.1|1.0.1|T|
||pt::peg::export::container|1|1|T|
||pt::peg::export::json|1|1|T|
||pt::peg::export::peg|1|1|T|
||pt::peg::from::json|1|1|T|
||pt::peg::from::peg|1.0.3|1.0.3|T|
||pt::peg::import|1.0.1|1.0.1|T|
||pt::peg::import::json|1|1|T|
||pt::peg::import::peg|1|1|T|
||pt::peg::interp|1.0.1|1.0.1|T|
||pt::peg::op|1.1.0|1.1.0|T|
||pt::peg::to::container|1|1|T|
||pt::peg::to::cparam|1.1.3|1.1.3|T|
||pt::peg::to::json|1|1|T|
||pt::peg::to::param|1.0.1|1.0.1|T|
||pt::peg::to::peg|1.0.2|1.0.2|T|
||pt::peg::to::tclparam|1.0.3|1.0.3|T|
||pt::pgen|1.1|1.1|T|
||pt::rde|1.1|1.1|I T|
||pt::tclparam::configuration::nx|1.0.1|1.0.1|T|
||pt::tclparam::configuration::snit|1.0.2|1.0.2|T|
||pt::tclparam::configuration::tcloo|1.0.4|1.0.4|T|
||||||
|struct|struct::graph|1.2.1|1.2.1|I|
||struct::graph|2.4.3|2.4.3|I|
||struct::queue|1.4.5|1.4.5|I|
||struct::skiplist|1.3|1.3|T|
||struct::stack|1.5.3|1.5.3|I|
||struct::tree|1.2.2|1.2.2|I T|
||struct::tree|2.1.2|2.1.2|I T|
||||||
|tar|tar|0.11|0.11|D|
||||||
|textutil|textutil::adjust|0.7.3|0.7.3|T|
||textutil::patch|0.1|0.1|I T|
|tool|tool|0.7|0.7|I|
|yaml|yaml|0.4.1|0.4.1|I|
||||||

Unchanged
=========

    aes, ascii85, autoproxy, base32, base32::core, base32::hex, bee,
    bench, bench::in, bench::out::csv, bench::out::text, blowfish,
    cache::async, calendar, cksum, clay, configuration, control,
    counter, cron, csv, debug, debug::caller, debug::heartbeat,
    debug::timestamp, defer, des, dicttool, docstrip,
    docstrip::util, doctools, doctools::changelog, doctools::config,
    doctools::cvs, doctools::html, doctools::html::cssdefaults,
    doctools::idx, doctools::idx, doctools::msgcat,
    doctools::msgcat::idx::c, doctools::msgcat::idx::de,
    doctools::msgcat::idx::en, doctools::msgcat::idx::fr,
    doctools::msgcat::toc::c, doctools::msgcat::toc::de,
    doctools::msgcat::toc::en, doctools::msgcat::toc::fr,
    doctools::nroff::man_macros, doctools::paths, doctools::text,
    doctools::toc, doctools::toc, dtplite, exif, fileutil::decode,
    fileutil::multi, fileutil::multi::op, fileutil::paths,
    fileutil::traverse, ftp, ftp::geturl, ftpd, gpx,
    grammar::aycock, grammar::aycock::debug,
    grammar::aycock::runtime, grammar::fa::dacceptor,
    grammar::fa::dexec, grammar::fa::op, grammar::me::cpu,
    grammar::me::cpu::core, grammar::me::cpu::gasm,
    grammar::me::tcl, grammar::me::util, grammar::peg,
    grammar::peg::interp, html, htmlparse, huddle::json, ident,
    imap4, interp, interp::delegate::method, interp::delegate::proc,
    ip, javascript, jpeg, json, lambda, lazyset, log, logger,
    logger::appender, logger::utils, map::geocode::nominatim,
    map::slippy, map::slippy::cache, map::slippy::fetcher, math,
    math::bignum, math::calculus, math::calculus::symdiff,
    math::complexnumbers, math::constants, math::exact, math::fuzzy,
    math::interpolate, math::linearalgebra, math::optimize,
    math::PCA, math::polynomials, math::rationalfunctions,
    math::roman, math::statistics, math::trig, md4, md5crypt,
    multiplexer, nameserv, nameserv::auto, nameserv::common,
    nameserv::server, ncgi, nettool, nmea, nntp, oauth, oo::dialect,
    oo::option, oo::util, otp, page::analysis::peg::emodes,
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
    page::writer::tree, paths, pluginmgr, png, pop3d, pop3d::dbox,
    pop3d::udb, practcl, pt::peg::container::peg, pt::rde::nx,
    pt::rde::oo, pt::util, rc4, rcs, report, resolv, ripemd128,
    ripemd160, SASL, SASL::NTLM, SASL::SCRAM, SASL::XGoogleToken,
    sha1, sha256, simulation::annealing, simulation::montecarlo,
    simulation::random, smtpd, snit, soundex, spf, stooop,
    string::token, string::token::shell, stringprep,
    stringprep::data, struct, struct::disjointset,
    struct::graph::op, struct::map, struct::matrix, struct::pool,
    struct::prioqueue, struct::record, struct::set, sum, switched,
    tcl::chan::cat, tcl::chan::core, tcl::chan::events,
    tcl::chan::facade, tcl::chan::fifo, tcl::chan::fifo2,
    tcl::chan::memchan, tcl::chan::null, tcl::chan::nullzero,
    tcl::chan::random, tcl::chan::std, tcl::chan::string,
    tcl::chan::textwindow, tcl::chan::variable, tcl::chan::zero,
    tcl::randomseed, tcl::transform::adler32,
    tcl::transform::base64, tcl::transform::core,
    tcl::transform::counter, tcl::transform::crc32,
    tcl::transform::hex, tcl::transform::identity,
    tcl::transform::limitsize, tcl::transform::observe,
    tcl::transform::otp, tcl::transform::rot,
    tcl::transform::spacer, tcl::transform::zlib, tclDES, tclDESjr,
    tepam, tepam::doc_gen, term, term::ansi::code,
    term::ansi::code::attr, term::ansi::code::macros,
    term::ansi::ctrl::unix, term::ansi::send, term::interact::menu,
    term::interact::pager, term::receive, term::receive::bind,
    term::send, text::write, textutil, textutil::expander,
    textutil::repeat, textutil::split, textutil::string,
    textutil::tabify, textutil::trim, textutil::wcswidth, throw,
    tiff, time, transfer::connect, transfer::copy,
    transfer::copy::queue, transfer::data::destination,
    transfer::data::source, transfer::receiver,
    transfer::transmitter, treeql, try, udpcluster, uevent,
    uevent::onidle, unicode, unicode::data, units, uri, uri::urn,
    uuencode, uuid, valtype::common, valtype::creditcard::amex,
    valtype::creditcard::discover, valtype::creditcard::mastercard,
    valtype::creditcard::visa, valtype::gs1::ean13, valtype::iban,
    valtype::imei, valtype::isbn, valtype::luhn, valtype::luhn5,
    valtype::usnpi, valtype::verhoeff, wip, xsxp, zipfile::encode,
    zipfile::mkzip
