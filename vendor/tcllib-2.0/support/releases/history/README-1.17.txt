Overview
========

    6   new packages                in 5   modules
    66  changed packages            in 39  modules
    46  internally changed packages in 31  modules
    293 unchanged packages          in 74  modules
    418 packages, total             in 118 modules, total

New in tcllib 1.17
==================

    Module       Package                          New Version   Comments
    ------------ -------------------------------- ------------- ----------
    cron         cron                             1.1
    nettool      nettool                          0.4
    oauth        oauth                            1
    processman   odie::processman                 0.3
    ------------ -------------------------------- ------------- ----------
    pt           pt::cparam::configuration::tea   0.1
                 pt::util                         1
    ------------ -------------------------------- ------------- ----------

Changes from tcllib 1.16 to 1.17
================================

                                                                 tcllib 1.16   tcllib 1.17
    Module                  Package                              Old Version   New Version   Comments
    ----------------------- ------------------------------------ ------------- ------------- ----------
    aes                     aes                                  1.1.1         1.2.1         I P
    amazon-s3               S3                                   1.0.0         1.0.3         B D P
    bibtex                  bibtex                               0.5           0.6           B EF
    cmdline                 cmdline                              1.3.3         1.5           D EF I T
    comm                    comm                                 4.6.2         4.6.3.1       B D
    ----------------------- ------------------------------------ ------------- ------------- ----------
    coroutine               coroutine                            1.1           1.1.3         B D
                            coroutine::auto                      1.1.1         1.1.3         B D
    ----------------------- ------------------------------------ ------------- ------------- ----------
    crc                     cksum                                1.1.3         1.1.4         B D I
                            crc32                                1.3.1         1.3.2         B D I
                            sum                                  1.1.0         1.1.2         B D I T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    debug                   debug                                1.0.2         1.0.5         B D EF
    ----------------------- ------------------------------------ ------------- ------------- ----------
    dns                     dns                                  1.3.3         1.3.5         B D I
                            ip                                   1.2.2         1.3           D EF I T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    doctools                doctools                             1.4.17        1.4.19        B D I
                            doctools::idx                        1.0.4         1.0.5         B D I
                            doctools::idx                        2             2             B D I
                            doctools::toc                        1.1.3         1.1.4         B D I
                            doctools::toc                        2             2             B D I
    ----------------------- ------------------------------------ ------------- ------------- ----------
    doctools2idx            doctools::idx                        1.0.4         1.0.5         B D I
                            doctools::idx                        2             2             B D I
    ----------------------- ------------------------------------ ------------- ------------- ----------
    doctools2toc            doctools::toc                        1.1.3         1.1.4         B D I
                            doctools::toc                        2             2             B D I
    ----------------------- ------------------------------------ ------------- ------------- ----------
    dtplite                 dtplite                              1.1           1.2           D I
    ----------------------- ------------------------------------ ------------- ------------- ----------
    fileutil                fileutil                             1.14.6        1.14.10       B D T
                            fileutil::traverse                   0.4.3         0.5           B D T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    ftp                     ftp                                  2.4.12        2.4.13        B D
    html                    html                                 1.4           1.4.4         B D T
    inifile                 inifile                              0.2.5         0.3           D EF I T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    json                    json                                 1.3.2         1.3.3         B D T
                            json::write                          1.0.2         1.0.3         B D T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    log                     logger                               0.9.3         0.9.4         B D T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    math                    math::bigfloat                       1.2.2         1.2.2         B T
                            math::bigfloat                       2.0.1         2.0.2         B T
                            math::calculus                       0.7.2         0.8.1         B D EF T
                            math::linearalgebra                  1.1.4         1.1.5         B D T
                            math::optimize                       1.0           1.0.1         B T
                            math::special                        0.2.2         0.3.0         D EF T
                            math::statistics                     0.9           0.9.3         B D EF T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    md4                     md4                                  1.0.5         1.0.6         B D I
    ncgi                    ncgi                                 1.4.2         1.4.3         B D T
    ooutil                  oo::util                             1.2           1.2.1         B D T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    pt                      char                                 1             1.0.1         D I T
                            pt::cparam::configuration::critcl    1.0.1         1.0.2         B D I T
                            pt::parse::peg                       1             1.0.1         B I T
                            pt::pe                               1             1.0.2         B D EF I
                            pt::peg::from::peg                   1.0.2         1.0.3         D EF
                            pt::peg::interp                      1             1.0.1         D EF
                            pt::peg::to::cparam                  1.0.1         1.1.3         B D EF
                            pt::peg::to::param                   1             1.0.1         B
                            pt::peg::to::peg                     1.0.1         1.0.2         D EF
                            pt::peg::to::tclparam                1             1.0.2         B D EF
                            pt::pgen                             1.0.2         1.0.3         EF T
                            pt::rde                              1.0.2         1.0.3         B D EF
                            pt::rde::oo                          1.0.2         1.0.3         B
                            pt::tclparam::configuration::snit    1.0.1         1.0.2         D EF
                            pt::tclparam::configuration::tcloo   1.0.3         1.0.4         D EF
    ----------------------- ------------------------------------ ------------- ------------- ----------
    report                  report                               0.3.1         0.3.2         D EF
    ----------------------- ------------------------------------ ------------- ------------- ----------
    ripemd                  ripemd128                            1.0.4         1.0.5         B D I
                            ripemd160                            1.0.4         1.0.5         B D I
    ----------------------- ------------------------------------ ------------- ------------- ----------
    sha1                    sha1                                 1.1.0         1.1.1         B I T
                            sha1                                 2.0.3         2.0.3         B I T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    string                  string::token::shell                 1.1           1.2           D EF T
    struct                  struct::pool                         1.2.1         1.2.3         D I T
    tar                     tar                                  0.9           0.10          B D T
    tepam                   tepam                                0.5.0         0.5           I
    textutil                textutil::adjust                     0.7.1         0.7.3         B D T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    uri                     uri                                  1.2.4         1.2.5         B D T
                            uri::urn                             1.0.2         1.0.3         B D I T
    ----------------------- ------------------------------------ ------------- ------------- ----------
    uuid                    uuid                                 1.0.2         1.0.4         B D I
    valtype                 valtype::iban                        1.4           1.5           B D EF T
    virtchannel_transform   tcl::transform::zlib                 1             1.0.1         B
    websocket               websocket                            1.3           1.4           B D EF
    yaml                    yaml                                 0.3.6         0.3.7         B D T
    zip                     zipfile::decode                      0.4           0.6.1         B D EF
    ----------------------- ------------------------------------ ------------- ------------- ----------

Invisible changes (documentation, testsuites)
=============================================

                                              tcllib 1.16   tcllib 1.17
    Module      Package                       Old Version   New Version   Comments
    ----------- ----------------------------- ------------- ------------- ----------
    amazon-s3   xsxp                          1.0           1.0           D
    ----------- ----------------------------- ------------- ------------- ----------
    base32      base32                        0.1           0.1           I
                base32::hex                   0.1           0.1           I
    ----------- ----------------------------- ------------- ------------- ----------
    base64      uuencode                      1.1.5         1.1.5         I
                yencode                       1.1.3         1.1.3         I
    ----------- ----------------------------- ------------- ------------- ----------
    blowfish    blowfish                      1.0.4         1.0.4         I
    calendar    calendar                      0.2           0.2           I
    control     control                       0.1.3         0.1.3         I
    crc         crc16                         1.1.2         1.1.2         D I
    des         des                           1.1.0         1.1.0         I
    ----------- ----------------------------- ------------- ------------- ----------
    dns         resolv                        1.0.3         1.0.3         I
                spf                           1.1.1         1.1.1         I
    ----------- ----------------------------- ------------- ------------- ----------
    http        autoproxy                     1.5.3         1.5.3         D I
    imap4       imap4                         0.5.2         0.5.2         D
    ----------- ----------------------------- ------------- ------------- ----------
    irc         irc                           0.6.1         0.6.1         I
                picoirc                       0.5.1         0.5.1         I
    ----------- ----------------------------- ------------- ------------- ----------
    ldap        ldap                          1.8           1.8           D
    log         logger::utils                 1.3           1.3           D
    math        math                          1.2.5         1.2.5         I
    ----------- ----------------------------- ------------- ------------- ----------
    md5         md5                           1.4.4         1.4.4         I
                md5                           2.0.7         2.0.7         I
    ----------- ----------------------------- ------------- ------------- ----------
    md5crypt    md5crypt                      1.1.0         1.1.0         I
    mime        smtp                          1.4.5         1.4.5         D I
    ntp         time                          1.2.1         1.2.1         I
    otp         otp                           1.0.0         1.0.0         I
    pop3        pop3                          1.9           1.9           D
    ----------- ----------------------------- ------------- ------------- ----------
    pop3d       pop3d                         1.1.0         1.1.0         I T
                pop3d::dbox                   1.0.2         1.0.2         I T
                pop3d::udb                    1.1           1.1           I
    ----------- ----------------------------- ------------- ------------- ----------
    pt          pt::peg::op                   1.0.1         1.0.1         D
    rc4         rc4                           1.1.0         1.1.0         I
    rest        rest                          1.0.1         1.0.1         D
    ----------- ----------------------------- ------------- ------------- ----------
    sasl        SASL                          1.3.3         1.3.3         I
                SASL::NTLM                    1.1.2         1.1.2         I
                SASL::SCRAM                   0.1           0.1           I
                SASL::XGoogleToken            1.0.1         1.0.1         D I
    ----------- ----------------------------- ------------- ------------- ----------
    sha1        sha256                        1.0.3         1.0.3         I T
    smtpd       smtpd                         1.5           1.5           D I
    ----------- ----------------------------- ------------- ------------- ----------
    struct      struct::matrix                1.2.1         1.2.1         D
                struct::matrix                2.0.3         2.0.3         D
    ----------- ----------------------------- ------------- ------------- ----------
    tepam       tepam::doc_gen                0.1.1         0.1.1         I
    ----------- ----------------------------- ------------- ------------- ----------
    transfer    transfer::connect             0.2           0.2           D
                transfer::copy                0.3           0.3           D
                transfer::copy::queue         0.1           0.1           D
                transfer::data::destination   0.2           0.2           D
                transfer::data::source        0.2           0.2           D
                transfer::receiver            0.2           0.2           D
                transfer::transmitter         0.2           0.2           D
    ----------- ----------------------------- ------------- ------------- ----------

Unchanged
=========

    ascii85, asn, base32::core, base64, bee, bench, bench::in,
    bench::out::csv, bench::out::text, cache::async, clock::iso8601,
    clock::rfc2822, configuration, counter, csv, debug::caller,
    debug::heartbeat, debug::timestamp, docstrip, docstrip::util,
    doctools::changelog, doctools::config, doctools::cvs,
    doctools::html, doctools::html::cssdefaults,
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
    doctools::toc::export, doctools::toc::export::doctoc,
    doctools::toc::export::html, doctools::toc::export::json,
    doctools::toc::export::nroff, doctools::toc::export::text,
    doctools::toc::export::wiki, doctools::toc::import,
    doctools::toc::import::doctoc, doctools::toc::import::json,
    doctools::toc::parse, doctools::toc::structure, exif,
    fileutil::decode, fileutil::magic::cfront,
    fileutil::magic::cgen, fileutil::magic::filetype,
    fileutil::magic::mimetype, fileutil::magic::rt, fileutil::multi,
    fileutil::multi::op, ftp::geturl, ftpd, generator, gpx,
    grammar::aycock, grammar::aycock::debug,
    grammar::aycock::runtime, grammar::fa, grammar::fa::dacceptor,
    grammar::fa::dexec, grammar::fa::op, grammar::me::cpu,
    grammar::me::cpu::core, grammar::me::cpu::gasm,
    grammar::me::tcl, grammar::me::util, grammar::peg,
    grammar::peg::interp, hook, htmlparse, huddle, ident, interp,
    interp::delegate::method, interp::delegate::proc, javascript,
    jpeg, lambda, ldapx, log, logger::appender,
    map::geocode::nominatim, map::slippy, map::slippy::cache,
    map::slippy::fetcher, mapproj, math::bignum,
    math::calculus::symdiff, math::complexnumbers, math::constants,
    math::decimal, math::fourier, math::fuzzy, math::geometry,
    math::interpolate, math::machineparameters, math::numtheory,
    math::polynomials, math::rationalfunctions, math::roman, mime,
    multiplexer, nameserv, nameserv::auto, nameserv::common,
    nameserv::server, namespacex, nmea, nntp,
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
    page::writer::tree, paths, pki, pluginmgr, png, profiler,
    pt::ast, pt::pe::op, pt::peg, pt::peg::container,
    pt::peg::container::peg, pt::peg::export,
    pt::peg::export::container, pt::peg::export::json,
    pt::peg::export::peg, pt::peg::from::json, pt::peg::import,
    pt::peg::import::json, pt::peg::import::peg,
    pt::peg::to::container, pt::peg::to::json, rcs,
    simulation::annealing, simulation::montecarlo,
    simulation::random, snit, soundex, stooop, string::token,
    stringprep, stringprep::data, struct, struct::disjointset,
    struct::graph, struct::graph::op, struct::list,
    struct::prioqueue, struct::queue, struct::record, struct::set,
    struct::skiplist, struct::stack, struct::tree, switched,
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
    tcl::transform::spacer, tclDES, tclDESjr, term,
    term::ansi::code, term::ansi::code::attr,
    term::ansi::code::ctrl, term::ansi::code::macros,
    term::ansi::ctrl::unix, term::ansi::send, term::interact::menu,
    term::interact::pager, term::receive, term::receive::bind,
    term::send, text::write, textutil, textutil::expander,
    textutil::repeat, textutil::split, textutil::string,
    textutil::tabify, textutil::trim, tie, tie::std::array,
    tie::std::dsource, tie::std::file, tie::std::growfile,
    tie::std::log, tie::std::rarray, tiff, treeql, try, uevent,
    uevent::onidle, unicode, unicode::data, units, valtype::common,
    valtype::creditcard::amex, valtype::creditcard::discover,
    valtype::creditcard::mastercard, valtype::creditcard::visa,
    valtype::gs1::ean13, valtype::imei, valtype::isbn,
    valtype::luhn, valtype::luhn5, valtype::usnpi,
    valtype::verhoeff, wip, zipfile::encode

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
    
