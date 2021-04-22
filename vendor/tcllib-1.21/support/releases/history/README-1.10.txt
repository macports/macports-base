Overview
========

  7 new packages in 4 new modules and 1 module with 2 new packages.
 43 changed packages.
164 unchanged packages (or non-visible changes, like testsuites)

New in Tcllib 1.10
==================
                                        Tcllib 1.10
Module          Package                 New Version     Comments
------          -------                 -----------     -----------------------
fileutil        fileutil::multi                 0.1      multi-file operations
                fileutil::multi::op             0.5      ditto, OO API
------          -------                 -----------     -----------------------
mapproj         mapproj                         1.0     Map projections.
------          -------                 -----------     -----------------------
nns             nameserv                        0.3      nameservice client
                nameserv::auto                  0.1      nameservice extended client
                nameserv::common                0.1      nameservice shared code
                nameserv::server                0.3      nameservice server
------          -------                 -----------     -----------------------
uev             uevent                          0.1.2    user events
------          -------                 -----------     -----------------------
wip             wip                             1.0      word interpreter Tcl 8.4
                wip                             2.0      word interpreter Tcl 8.5
------          -------                 -----------     -----------------------

Changes from Tcllib 1.9 to 1.10
===============================

Legend  Change  Details Comments
        Major   API:    ** incompatible ** API changes.

        Minor   EF :    Extended functionality, API.
                I  :    Major rewrite, but no API change

        Patch   B  :    Bug fixes.
                EX :    New examples.
                P  :    Performance enhancement.

        None    T  :    Testsuite changes.
                D  :    Documentation updates.

                                Tcllib 1.9      Tcllib 1.10
Module          Package         Old version     New Version     Comments
------          -------         -----------     -----------     ---------------
asn             asn                0.7          0.8.1           D, B
base64          uuencode           1.1.3        1.1.4           B, D
------          -------         -----------     -----------     ---------------
bench           bench              0.1          0.3.1           EF, D, B
                bench::out::csv    0.1.1        0.1.2           B
                bench::out::text   0.1.1        0.1.2           B
------          -------         -----------     -----------     ---------------
blowfish        blowfish           1.0.2        1.0.3           B, D
comm            comm               4.4          4.5.6           EF (futures), B, D
des             des                1.0.0        1.1.0           EF (padding), D
------          -------         -----------     -----------     ---------------
dns             dns                1.3.1        1.3.3           B, D
                ip                 1.1.1        1.1.2           B, D
------          -------         -----------     -----------     ---------------
doctools        doctools           1.2.1        1.3             EF (syntax), B, D, T
                doctools::idx      0.2.1        0.3             EF (syntax), D, T
                doctools::toc      0.2.1        0.3             EF (syntax), D, T
------          -------         -----------     -----------     ---------------
fileutil        fileutil           1.9          1.13.3          EF, B, T, D
                fileutil::traverse 0.1          0.3             B
------          -------         -----------     -----------     ---------------
ftp             ftp                2.4.4        2.4.8           B
ftpd            ftpd               1.2.2        1.2.3           B, D
------          -------         -----------     -----------     ---------------
grammar_fa      grammar::fa        0.2          0.3             EF, D
                grammar::fa::dexec 0.1.1        0.2             EF (ext. introspection), D
                grammar::fa::op    0.2          0.4             EF (nullary .|, 2regexp), D
------          -------         -----------     -----------     ---------------
http            autoproxy          1.3          1.4             B, D
inifile         inifile            0.2          0.2.1           B, D
interp          interp             0.1          0.1.1           B, D, T
------          -------         -----------     -----------     ---------------
ldap            ldap               1.6.6        1.6.8           B, D
                ldapx              0.2.2        1.0             API, B
------          -------         -----------     -----------     ---------------
log             logger             0.7          0.8             EF, D
------          -------         -----------     -----------     ---------------
math            math::linearalgebra 1.0.1       1.0.2           B, D
                math::special      0.2          0.2.1           B, D
                math::statistics   0.3          0.5             EF (mv linreg), D, T
------          -------         -----------     -----------     ---------------
mime            mime               1.5.1        1.5.2           B, T, D
                smtp               1.4.2        1.4.4           B, D
------          -------         -----------     -----------     ---------------
nmea            nmea               0.1          0.1.1           B, D
page            page::compiler::peg::mecpu 0.1  0.1.1           B
png             png                0.1.1        0.1.2           B, D, T
------          -------         -----------     -----------     ---------------
sasl            SASL::NTLM         1.1.0        1.1.1           B, D
                SASL::XGoogleToken 1.0.0        1.0.1           B, D
------          -------         -----------     -----------     ---------------
sha1            sha1               2.0.2        2.0.3           B, D, T
                sha256             1.0.1        1.0.2           B, D, T
------          -------         -----------     -----------     ---------------
snit            snit               1.2          1.3.1           EF (introspection, -class), B
                snit               2.1          2.2.1           EF (introspection, -class), B
------          -------         -----------     -----------     ---------------
struct          struct::graph      2.1          2.2             EF (Critcl), T, D
                struct::list       1.6          1.6.1           B
                struct::set        2.1.1        2.2.1           EF (Critcl), B, T, D
------          -------         -----------     -----------     ---------------
tar             tar                0.2          0.4             B, D
uri             uri                1.2          1.2.1           B, D
------          -------         -----------     -----------     ---------------


Invisible or no changes
------          -------         -----------     -----------     ---------------
aes             aes                             1.0.0           D
base32          base32                          0.1             D
                base32::core                    0.1             D
                base32::hex                     0.1             D
base64          base64                          2.3.2           D
                yencode                         1.1.1           D
bee             bee                             0.1             D
bench           bench::in                       0.1             D
bibtex          bibtex                          0.5             D
calendar        calendar                        0.2
cmdline         cmdline                         1.3             D, T
control         control                         0.1.3           D
counter         counter                         2.0.4           D
crc             cksum                           1.1.1           D
                crc16                           1.1.1           D
                crc32                           1.3             D
                sum                             1.1.0           D
csv             csv                             0.7             D
des             tclDES                          1.0.0
                tclDESjr                        1.0.0
dns             ip                              1.1.1           B
                resolv                          1.0.3
                spf                             1.1.0
docstrip        docstrip                        1.2
                docstrip::util                  1.2
doctools        doctools::changelog             0.1.1
                doctools::cvs                   0.1.1
exif            exif                            1.1.2           D
ftp             ftp::geturl                     0.2
fumagic         fileutil::magic::cfront         1.0
                fileutil::magic::cgen           1.0
                fileutil::magic::filetype       1.0.2           D
                fileutil::magic::mimetype       1.0.2           D
                fileutil::magic::rt             1.0
grammar_fa      grammar::fa::dacceptor          0.1.1           D
grammar_me      grammar::me::cpu                0.2             D, T
                grammar::me::cpu::core          0.2             D, T
                grammar::me::cpu::gasm          0.1             D, T
                grammar::me::tcl                0.1             D, T
                grammar::me::util               0.1             D, T
grammar_peg     grammar::peg                    0.1             D
                grammar::peg::interp            0.1             D
html            html                            1.4             D
htmlparse       htmlparse                       1.1.2           D, T
ident           ident                           0.42            D
interp          interp::delegate::method        0.2
                interp::delegate::proc          0.2
irc             irc                             0.6             D
javascript      javascript                      1.0.2           D
jpeg            jpeg                            0.3             D
json            json                            1.0             D
log             log                             1.2             D
                logger::appender                1.3             D
                logger::utils                   1.3             D
math            math                            1.2.4           D
                math::bigfloat                  1.2.1           D
                math::bigfloat                  2.0             D
                math::bignum                    3.1.1           D
                math::calculus                  0.7             D
                math::complexnumbers            1.0.2           D
                math::constants                 1.0.1           D
                math::fourier                   1.0.2           D
                math::fuzzy                     0.2             T, D
                math::geometry                  1.0.3           D
                math::interpolate               1.0.2           D
                math::optimize                  1.0             D
                math::polynomials               1.0.1           D
                math::rationalfunctions         1.0.1           D
                math::roman                     1.0             D
md4             md4                             1.0.4           D
md5             md5                             1.4.4           D
                md5                             2.0.5           D
md5crypt        md5crypt                        1.0.0           D
multiplexer     multiplexer                     0.2             D, T
ncgi            ncgi                            1.3.2           D, T
nntp            nntp                            0.2.1           D
ntp             time                            1.2.1           D
otp             otp                             1.0.0           D
page            page::analysis::peg::emodes     0.1
                page::analysis::peg::minimize   0.1
                page::analysis::peg::reachable  0.1
                page::analysis::peg::realizable 0.1
                page::gen::peg::canon           0.1
                page::gen::peg::cpkg            0.1
                page::gen::peg::hb              0.1
                page::gen::peg::me              0.1
                page::gen::peg::mecpu           0.1
                page::gen::peg::ser             0.1
                page::gen::tree::text           0.1
                page::parse::lemon              0.1
                page::parse::peg                0.1
                page::parse::peghb              0.1
                page::parse::pegser             0.1
                page::pluginmgr                 0.2
                page::util::flow                0.1
                page::util::norm::lemon         0.1
                page::util::norm::peg           0.1
                page::util::peg                 0.1
                page::util::quote               0.1
pluginmgr       pluginmgr                       0.1             D
pop3            pop3                            1.6.3           D, T
pop3d           pop3d                           1.1.0           D, T
                pop3d::dbox                     1.0.2           D
                pop3d::udb                      1.1             D
profiler        profiler                        0.3             D
rc4             rc4                             1.1.0           D
rcs             rcs                             0.1             D
report          report                          0.3.1           D
ripemd          ripemd128                       1.0.3           D
                ripemd160                       1.0.3           D
sasl            SASL                            1.3.1           D
                sha1                            1.1.0           D, T
smtpd           smtpd                           1.4.0           D
soundex         soundex                         1.0             D
stooop          stooop                          4.4.1           D, T
                switched                        2.2.1
struct          struct                          1.4             D
                struct                          2.1             D
                struct::graph                   1.2.1           D
                struct::matrix                  1.2.1           D
                struct::matrix                  2.0.1           D
                struct::pool                    1.2.1           D
                struct::prioqueue               1.3.1           D
                struct::queue                   1.4             D
                struct::record                  1.2.1           D
                struct::skiplist                1.3             D
                struct::stack                   1.3.1           D
                struct::tree                    1.2.2           D
                struct::tree                    2.1.1           D
term            term                            0.1             D
                term::interact::menu            0.1             D
                term::interact::pager           0.1             D
                term::receive                   0.1             D
                term::receive::bind             0.1             D
                term::send                      0.1             D
textutil        textutil                        0.7.1           D
                textutil::adjust                0.7             D
                textutil::expander              1.3.1           D
                textutil::repeat                0.7             D
                textutil::split                 0.7             D
                textutil::string                0.7             D
                textutil::tabify                0.7             D
                textutil::trim                  0.7             D
tie             tie                             1.1             D, T
                tie::std::array                 1.0             D, T
                tie::std::dsource               1.0             D, T
                tie::std::file                  1.0.2           D, T
                tie::std::growfile              1.0             D, T
                tie::std::log                   1.0             D, T
                tie::std::rarray                1.0             D, T
tiff            tiff                            0.1             D
transfer        transfer::connect               0.1             D
                transfer::copy                  0.1             D
                transfer::copy::queue           0.1             D
                transfer::data::destination     0.1             D
                transfer::data::source          0.1             D
                transfer::receiver              0.1             D
                transfer::transmitter           0.1             D
treeql          treeql                          1.3.1           D, T
units           units                           2.1             D
uri             uri::urn                        1.0.2           D
uuid            uuid                            1.0.1           D
------          -------         -----------     -----------     ---------------
