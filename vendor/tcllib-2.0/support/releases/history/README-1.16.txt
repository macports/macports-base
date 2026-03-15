Overview
========

    11  new packages                in 7   modules
    45  changed packages            in 26  modules
    288 internally changed packages in 100 modules
    61  unchanged packages          in 11  modules
    411 packages, total             in 114 modules, total

New in tcllib 1.16
==================

    Module      Package                New Version   Comments
    ----------- ---------------------- ------------- ----------
    debug       debug                  1.0.2
                debug::caller          1
                debug::heartbeat       1
                debug::timestamp       1
    ----------- ---------------------- ------------- ----------
    dtplite     dtplite                1.1
    pt          pt::rde::oo            1.0.2
    sasl        SASL::SCRAM            0.1
    ----------- ---------------------- ------------- ----------
    string      string::token          1
                string::token::shell   1.1
    ----------- ---------------------- ------------- ----------
    tepam       tepam::doc_gen         0.1.1
    websocket   websocket              1.3
    ----------- ---------------------- ------------- ----------

Changes from tcllib 1.15 to 1.16
================================

                                                            tcllib 1.15   tcllib 1.16
    Module             Package                              Old Version   New Version   Comments
    ------------------ ------------------------------------ ------------- ------------- ----------
    aes                aes                                  1.1           1.1.1         B D T
    coroutine          coroutine::auto                      1.1           1.1.1         B D
    dns                ip                                   1.2           1.2.2         B D T
    ------------------ ------------------------------------ ------------- ------------- ----------
    doctools           doctools                             1.4.14        1.4.17        B D T
                       doctools::changelog                  1             1.1           D
    ------------------ ------------------------------------ ------------- ------------- ----------
    fileutil           fileutil                             1.14.5        1.14.6        B D T
                       fileutil::decode                     0.1           0.2           B
    ------------------ ------------------------------------ ------------- ------------- ----------
    ftp                ftp                                  2.4.11        2.4.12        B D
    grammar_fa         grammar::fa                          0.4           0.5           B D
    imap4              imap4                                0.4           0.5.2         B D EF
    jpeg               jpeg                                 0.4.0         0.5           B D T
    json               json                                 1.1.2         1.3.2         D EF T
    ------------------ ------------------------------------ ------------- ------------- ----------
    math               math::calculus                       0.7.1         0.7.2         B D
                       math::decimal                        1.0.2         1.0.3         B D
                       math::geometry                       1.1.2         1.1.3         B D
                       math::interpolate                    1.0.3         1.1           B D T
                       math::statistics                     0.8.0         0.9           D EF T
    ------------------ ------------------------------------ ------------- ------------- ----------
    mime               mime                                 1.5.6         1.6           D EF T
    ncgi               ncgi                                 1.4.1         1.4.2         B D T
    ooutil             oo::util                             1.1           1.2           D EF
    ------------------ ------------------------------------ ------------- ------------- ----------
    pt                 pt::peg::from::peg                   1             1.0.2         B D T
                       pt::peg::op                          1             1.0.1         B D
                       pt::peg::to::peg                     1             1.0.1         B D T
                       pt::pgen                             1.0.1         1.0.2         B D
                       pt::tclparam::configuration::tcloo   1.0.2         1.0.3         D T
    ------------------ ------------------------------------ ------------- ------------- ----------
    rest               rest                                 1.0           1.0.1         B D
    ------------------ ------------------------------------ ------------- ------------- ----------
    sasl               SASL                                 1.3.2         1.3.3         B D T
                       SASL::NTLM                           1.1.1         1.1.2         B D T
    ------------------ ------------------------------------ ------------- ------------- ----------
    struct             struct::list                         1.8.2         1.8.3         B D T
                       struct::matrix                       1.2.1         1.2.1         D
                       struct::matrix                       2.0.2         2.0.3         D
                       struct::queue                        1.4.4         1.4.5         B D T
    ------------------ ------------------------------------ ------------- ------------- ----------
    tar                tar                                  0.7.1         0.9           B D T
    tepam              tepam                                0.4.0         0.5.0         B D T
    ------------------ ------------------------------------ ------------- ------------- ----------
    term               term::ansi::code                     0.1           0.2           B D
                       term::ansi::code::ctrl               0.1.2         0.2           B D
                       term::ansi::send                     0.1           0.2           B D
    ------------------ ------------------------------------ ------------- ------------- ----------
    textutil           textutil                             0.7.1         0.8           D EF
                       textutil::string                     0.7.1         0.8           D EF T
    ------------------ ------------------------------------ ------------- ------------- ----------
    uri                uri                                  1.2.2         1.2.4         B D T
    valtype            valtype::iban                        1.1           1.4           D EF T
    ------------------ ------------------------------------ ------------- ------------- ----------
    virtchannel_base   tcl::chan::memchan                   1.0.2         1.0.3         B D
                       tcl::chan::string                    1.0.1         1.0.2         B D
                       tcl::chan::variable                  1.0.2         1.0.3         B D
    ------------------ ------------------------------------ ------------- ------------- ----------
    zip                zipfile::decode                      0.2           0.4           B D
                       zipfile::encode                      0.1           0.3           B D
    ------------------ ------------------------------------ ------------- ------------- ----------

Invisible changes (documentation, testsuites)
=============================================

                                                                tcllib 1.15   tcllib 1.16
    Module                  Package                             Old Version   New Version   Comments
    ----------------------- ----------------------------------- ------------- ------------- ----------
    amazon-s3               S3                                  1.0.0         1.0.0         D
                            xsxp                                1.0           1.0           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    asn                     asn                                 0.8.4         0.8.4         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    base32                  base32                              0.1           0.1           D
                            base32::core                        0.1           0.1           D
                            base32::hex                         0.1           0.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    base64                  ascii85                             1.0           1.0           D
                            base64                              2.4.2         2.4.2         D
                            uuencode                            1.1.5         1.1.5         D
                            yencode                             1.1.3         1.1.3         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    bee                     bee                                 0.1           0.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    bench                   bench                               0.4           0.4           D
                            bench::in                           0.1           0.1           D
                            bench::out::csv                     0.1.2         0.1.2         D
                            bench::out::text                    0.1.2         0.1.2         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    bibtex                  bibtex                              0.5           0.5           D
    blowfish                blowfish                            1.0.4         1.0.4         D
    cache                   cache::async                        0.3           0.3           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    clock                   clock::iso8601                      0.1           0.1           D T
                            clock::rfc2822                      0.1           0.1           D T
    ----------------------- ----------------------------------- ------------- ------------- ----------
    cmdline                 cmdline                             1.3.3         1.3.3         D
    comm                    comm                                4.6.2         4.6.2         D
    control                 control                             0.1.3         0.1.3         D
    coroutine               coroutine                           1.1           1.1           D
    counter                 counter                             2.0.4         2.0.4         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    crc                     cksum                               1.1.3         1.1.3         D
                            crc16                               1.1.2         1.1.2         D
                            crc32                               1.3.1         1.3.1         D
                            sum                                 1.1.0         1.1.0         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    csv                     csv                                 0.8           0.8           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    des                     des                                 1.1.0         1.1.0         D
                            tclDES                              1.0.0         1.0.0         D
                            tclDESjr                            1.0.0         1.0.0         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    dns                     dns                                 1.3.3         1.3.3         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    docstrip                docstrip                            1.2           1.2           D
                            docstrip::util                      1.3           1.3           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    doctools                doctools::cvs                       1             1             D
                            doctools::idx                       1.0.4         1.0.4         D
                            doctools::idx                       2             2             D
                            doctools::toc                       1.1.3         1.1.3         D
                            doctools::toc                       2             2             D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    doctools2base           doctools::html::cssdefaults         0.1           0.1           D
                            doctools::msgcat                    0.1           0.1           D
                            doctools::nroff::man_macros         0.1           0.1           D
                            doctools::tcl::parse                0.1           0.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    doctools2idx            doctools::idx                       1.0.4         1.0.4         D
                            doctools::idx                       2             2             D
                            doctools::idx::export               0.1           0.1           D
                            doctools::idx::export::html         0.2           0.2           D
                            doctools::idx::export::json         0.1           0.1           D
                            doctools::idx::export::nroff        0.3           0.3           D
                            doctools::idx::export::text         0.2           0.2           D
                            doctools::idx::export::wiki         0.2           0.2           D
                            doctools::idx::import               0.1           0.1           D
                            doctools::idx::import::json         0.1           0.1           D
                            doctools::idx::parse                0.1           0.1           D
                            doctools::idx::structure            0.1           0.1           D
                            doctools::msgcat::idx::c            0.1           0.1           D
                            doctools::msgcat::idx::de           0.1           0.1           D
                            doctools::msgcat::idx::en           0.1           0.1           D
                            doctools::msgcat::idx::fr           0.1           0.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    doctools2toc            doctools::msgcat::toc::c            0.1           0.1           D
                            doctools::msgcat::toc::de           0.1           0.1           D
                            doctools::msgcat::toc::en           0.1           0.1           D
                            doctools::msgcat::toc::fr           0.1           0.1           D
                            doctools::toc                       1.1.3         1.1.3         D
                            doctools::toc                       2             2             D
                            doctools::toc::export               0.1           0.1           D
                            doctools::toc::export::html         0.1           0.1           D
                            doctools::toc::export::json         0.1           0.1           D
                            doctools::toc::export::nroff        0.2           0.2           D
                            doctools::toc::export::text         0.1           0.1           D
                            doctools::toc::export::wiki         0.1           0.1           D
                            doctools::toc::import               0.1           0.1           D
                            doctools::toc::import::json         0.1           0.1           D
                            doctools::toc::parse                0.1           0.1           D
                            doctools::toc::structure            0.1           0.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    exif                    exif                                1.1.2         1.1.2         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    fileutil                fileutil::multi                     0.1           0.1           D
                            fileutil::multi::op                 0.5.3         0.5.3         D
                            fileutil::traverse                  0.4.3         0.4.3         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    ftp                     ftp::geturl                         0.2.1         0.2.1         D
    ftpd                    ftpd                                1.2.6         1.2.6         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    fumagic                 fileutil::magic::cfront             1.0           1.0           D
                            fileutil::magic::cgen               1.0           1.0           D
                            fileutil::magic::filetype           1.0.2         1.0.2         D
                            fileutil::magic::mimetype           1.0.2         1.0.2         D
                            fileutil::magic::rt                 1.0           1.0           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    generator               generator                           0.1           0.1           D
    gpx                     gpx                                 1             1             D
    grammar_aycock          grammar::aycock                     1.0           1.0           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    grammar_fa              grammar::fa::dacceptor              0.1.1         0.1.1         D
                            grammar::fa::dexec                  0.2           0.2           D
                            grammar::fa::op                     0.4.1         0.4.1         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    grammar_me              grammar::me::cpu                    0.2           0.2           D
                            grammar::me::cpu::core              0.2           0.2           D
                            grammar::me::cpu::gasm              0.1           0.1           D
                            grammar::me::tcl                    0.1           0.1           D
                            grammar::me::util                   0.1           0.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    grammar_peg             grammar::peg                        0.2           0.2           D
                            grammar::peg::interp                0.1.1         0.1.1         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    hook                    hook                                0.1           0.1           D
    html                    html                                1.4           1.4           D
    htmlparse               htmlparse                           1.2.1         1.2.1         D
    http                    autoproxy                           1.5.3         1.5.3         D
    ident                   ident                               0.42          0.42          D
    inifile                 inifile                             0.2.5         0.2.5         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    interp                  interp                              0.1.2         0.1.2         D
                            interp::delegate::method            0.2           0.2           D
                            interp::delegate::proc              0.2           0.2           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    irc                     irc                                 0.6.1         0.6.1         D
                            picoirc                             0.5.1         0.5.1         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    javascript              javascript                          1.0.2         1.0.2         D
    json                    json::write                         1.0.2         1.0.2         D T
    lambda                  lambda                              1             1             D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    ldap                    ldap                                1.8           1.8           D
                            ldapx                               1.0           1.0           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    log                     log                                 1.3           1.3           D
                            logger                              0.9.3         0.9.3         D
                            logger::appender                    1.3           1.3           D
                            logger::utils                       1.3           1.3           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    map                     map::geocode::nominatim             0.1           0.1           D
                            map::slippy                         0.5           0.5           D
                            map::slippy::cache                  0.2           0.2           D
                            map::slippy::fetcher                0.3           0.3           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    mapproj                 mapproj                             1.0           1.0           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    math                    math                                1.2.5         1.2.5         D T
                            math::bigfloat                      1.2.2         1.2.2         D
                            math::bigfloat                      2.0.1         2.0.1         D
                            math::bignum                        3.1.1         3.1.1         D
                            math::calculus::symdiff             1.0           1.0           D
                            math::complexnumbers                1.0.2         1.0.2         D
                            math::constants                     1.0.1         1.0.1         D
                            math::fourier                       1.0.2         1.0.2         D
                            math::fuzzy                         0.2.1         0.2.1         D
                            math::linearalgebra                 1.1.4         1.1.4         D
                            math::machineparameters             0.1           0.1           D
                            math::numtheory                     1.0           1.0           D
                            math::optimize                      1.0           1.0           D
                            math::polynomials                   1.0.1         1.0.1         D
                            math::rationalfunctions             1.0.1         1.0.1         D
                            math::roman                         1.0           1.0           D
                            math::special                       0.2.2         0.2.2         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    md4                     md4                                 1.0.5         1.0.5         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    md5                     md5                                 1.4.4         1.4.4         D
                            md5                                 2.0.7         2.0.7         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    md5crypt                md5crypt                            1.1.0         1.1.0         D
    mime                    smtp                                1.4.5         1.4.5         D
    multiplexer             multiplexer                         0.2           0.2           D
    namespacex              namespacex                          0.1           0.1           D
    nmea                    nmea                                1.0.0         1.0.0         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    nns                     nameserv                            0.4.2         0.4.2         D
                            nameserv::auto                      0.3           0.3           D
                            nameserv::common                    0.1           0.1           D
                            nameserv::server                    0.3.2         0.3.2         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    nntp                    nntp                                0.2.1         0.2.1         D
    ntp                     time                                1.2.1         1.2.1         D
    otp                     otp                                 1.0.0         1.0.0         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    page                    page::pluginmgr                     0.2           0.2           D
                            page::util::flow                    0.1           0.1           D
                            page::util::norm::lemon             0.1           0.1           D
                            page::util::norm::peg               0.1           0.1           D
                            page::util::peg                     0.1           0.1           D
                            page::util::quote                   0.1           0.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    pki                     pki                                 0.6           0.6           D
    pluginmgr               pluginmgr                           0.3           0.3           D
    png                     png                                 0.2           0.2           D
    pop3                    pop3                                1.9           1.9           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    pop3d                   pop3d                               1.1.0         1.1.0         D
                            pop3d::dbox                         1.0.2         1.0.2         D
                            pop3d::udb                          1.1           1.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    profiler                profiler                            0.3           0.3           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    pt                      pt::ast                             1.1           1.1           D T
                            pt::cparam::configuration::critcl   1.0.1         1.0.1         T
                            pt::parse::peg                      1             1             D T
                            pt::pe                              1             1             D T
                            pt::pe::op                          1             1             D
                            pt::peg                             1             1             D T
                            pt::peg::container                  1             1             D
                            pt::peg::export                     1             1             D
                            pt::peg::export::json               1             1             T
                            pt::peg::export::peg                1             1             T
                            pt::peg::from::json                 1             1             T
                            pt::peg::import                     1             1             D
                            pt::peg::import::json               1             1             T
                            pt::peg::import::peg                1             1             T
                            pt::peg::interp                     1             1             D T
                            pt::peg::to::container              1             1             T
                            pt::peg::to::cparam                 1.0.1         1.0.1         T
                            pt::peg::to::json                   1             1             T
                            pt::peg::to::param                  1             1             T
                            pt::peg::to::tclparam               1             1             T
                            pt::rde                             1.0.2         1.0.2         D
                            pt::tclparam::configuration::snit   1.0.1         1.0.1         T
    ----------------------- ----------------------------------- ------------- ------------- ----------
    rc4                     rc4                                 1.1.0         1.1.0         D
    rcs                     rcs                                 0.1           0.1           D
    report                  report                              0.3.1         0.3.1         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    ripemd                  ripemd128                           1.0.4         1.0.4         D
                            ripemd160                           1.0.4         1.0.4         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    sasl                    SASL::XGoogleToken                  1.0.1         1.0.1         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    sha1                    sha1                                1.1.0         1.1.0         B D
                            sha1                                2.0.3         2.0.3         B D
                            sha256                              1.0.3         1.0.3         B D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    simulation              simulation::annealing               0.2           0.2           D
                            simulation::montecarlo              0.1           0.1           D
                            simulation::random                  0.3.1         0.3.1         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    smtpd                   smtpd                               1.5           1.5           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    snit                    snit                                1.4.2         1.4.2         D
                            snit                                2.3.2         2.3.2         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    soundex                 soundex                             1.0           1.0           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    stooop                  stooop                              4.4.1         4.4.1         D
                            switched                            2.2.1         2.2.1         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    stringprep              stringprep                          1.0.1         1.0.1         D
                            stringprep::data                    1.0.1         1.0.1         D
                            unicode                             1.0.0         1.0.0         D
                            unicode::data                       1.0.0         1.0.0         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    struct                  struct::disjointset                 1.0           1.0           D
                            struct::graph                       1.2.1         1.2.1         D
                            struct::graph                       2.4           2.4           D
                            struct::graph::op                   0.11.3        0.11.3        D
                            struct::pool                        1.2.1         1.2.1         D
                            struct::prioqueue                   1.4           1.4           D
                            struct::record                      1.2.1         1.2.1         D
                            struct::set                         2.2.3         2.2.3         D
                            struct::skiplist                    1.3           1.3           D
                            struct::stack                       1.5.3         1.5.3         D
                            struct::tree                        1.2.2         1.2.2         D
                            struct::tree                        2.1.2         2.1.2         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    term                    term                                0.1           0.1           D
                            term::ansi::code::attr              0.1           0.1           D
                            term::ansi::code::macros            0.1           0.1           D
                            term::ansi::ctrl::unix              0.1.1         0.1.1         D
                            term::interact::menu                0.1           0.1           D
                            term::interact::pager               0.1           0.1           D
                            term::receive                       0.1           0.1           D
                            term::receive::bind                 0.1           0.1           D
                            term::send                          0.1           0.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    textutil                textutil::adjust                    0.7.1         0.7.1         D
                            textutil::expander                  1.3.1         1.3.1         D T
                            textutil::repeat                    0.7           0.7           D
                            textutil::split                     0.7           0.7           D
                            textutil::tabify                    0.7           0.7           D
                            textutil::trim                      0.7           0.7           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    tie                     tie                                 1.1           1.1           D
    tiff                    tiff                                0.2.1         0.2.1         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    transfer                transfer::connect                   0.2           0.2           D
                            transfer::copy                      0.3           0.3           D
                            transfer::data::destination         0.2           0.2           D
                            transfer::data::source              0.2           0.2           D
                            transfer::receiver                  0.2           0.2           D
                            transfer::transmitter               0.2           0.2           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    treeql                  treeql                              1.3.1         1.3.1         D
    try                     try                                 1             1             D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    uev                     uevent                              0.3.1         0.3.1         D
                            uevent::onidle                      0.1           0.1           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    units                   units                               2.1.1         2.1.1         D
    uri                     uri::urn                            1.0.2         1.0.2         D
    uuid                    uuid                                1.0.2         1.0.2         D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    valtype                 valtype::common                     1             1             D
                            valtype::creditcard::amex           1             1             D
                            valtype::creditcard::discover       1             1             D
                            valtype::creditcard::mastercard     1             1             D
                            valtype::creditcard::visa           1             1             D
                            valtype::gs1::ean13                 1             1             D
                            valtype::imei                       1             1             D
                            valtype::isbn                       1             1             D
                            valtype::luhn                       1             1             D
                            valtype::luhn5                      1             1             D
                            valtype::usnpi                      1             1             D
                            valtype::verhoeff                   1             1             D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    virtchannel_base        tcl::chan::cat                      1.0.2         1.0.2         D
                            tcl::chan::facade                   1.0.1         1.0.1         D
                            tcl::chan::fifo                     1             1             D
                            tcl::chan::fifo2                    1             1             D
                            tcl::chan::halfpipe                 1             1             D
                            tcl::chan::null                     1             1             D
                            tcl::chan::nullzero                 1             1             D
                            tcl::chan::random                   1             1             D
                            tcl::chan::std                      1.0.1         1.0.1         D
                            tcl::chan::textwindow               1             1             D
                            tcl::chan::zero                     1             1             D
                            tcl::randomseed                     1             1             D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    virtchannel_core        tcl::chan::core                     1             1             D
                            tcl::chan::events                   1             1             D
                            tcl::transform::core                1             1             D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    virtchannel_transform   tcl::transform::adler32             1             1             D
                            tcl::transform::base64              1             1             D
                            tcl::transform::counter             1             1             D
                            tcl::transform::crc32               1             1             D
                            tcl::transform::hex                 1             1             D
                            tcl::transform::identity            1             1             D
                            tcl::transform::limitsize           1             1             D
                            tcl::transform::observe             1             1             D
                            tcl::transform::otp                 1             1             D
                            tcl::transform::rot                 1             1             D
                            tcl::transform::spacer              1             1             D
                            tcl::transform::zlib                1             1             D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    wip                     wip                                 1.2           1.2           D
                            wip                                 2.2           2.2           D
    ----------------------- ----------------------------------- ------------- ------------- ----------
    yaml                    huddle                              0.1.5         0.1.5         D
                            yaml                                0.3.6         0.3.6         D
    ----------------------- ----------------------------------- ------------- ------------- ----------

Unchanged
=========

    calendar, char, configuration, doctools::config, doctools::html,
    doctools::idx::export::docidx, doctools::idx::import::docidx,
    doctools::paths, doctools::text, doctools::toc::export::doctoc,
    doctools::toc::import::doctoc, grammar::aycock::debug,
    grammar::aycock::runtime, page::analysis::peg::emodes,
    page::analysis::peg::minimize, page::analysis::peg::reachable,
    page::analysis::peg::realizable, page::compiler::peg::mecpu,
    page::config::peg, page::gen::peg::canon, page::gen::peg::cpkg,
    page::gen::peg::hb, page::gen::peg::me, page::gen::peg::mecpu,
    page::gen::peg::ser, page::gen::tree::text, page::parse::lemon,
    page::parse::peg, page::parse::peghb, page::parse::pegser,
    page::reader::hb, page::reader::lemon, page::reader::peg,
    page::reader::ser, page::reader::treeser,
    page::transform::mecpu, page::transform::reachable,
    page::transform::realizable, page::writer::hb,
    page::writer::identity, page::writer::me, page::writer::mecpu,
    page::writer::null, page::writer::peg, page::writer::ser,
    page::writer::tpc, page::writer::tree, paths,
    pt::peg::container::peg, pt::peg::export::container, resolv,
    spf, struct, text::write, tie::std::array, tie::std::dsource,
    tie::std::file, tie::std::growfile, tie::std::log,
    tie::std::rarray, transfer::copy::queue

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
    
