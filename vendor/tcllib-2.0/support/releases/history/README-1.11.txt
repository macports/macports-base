Overview
========

 11 new packages in 4 new modules, and 2 new packages in 2 existing modules.
 62 changed packages.
159 unchanged packages (or non-visible changes, like testsuites)

New in Tcllib 1.11
==================
                                        Tcllib 1.10
Module          Package                 New Version     Comments
------          -------                 -----------     -----------------------
amazon-s3   	S3                            1.0.0     access to amazon's S3 service
            	xsxp                          1.0       XML processing helper
------          -------                 -----------     -----------------------
irc            	picoirc                       0.5.1     minimal irc client
------          -------                 -----------     -----------------------
simulation  	simulation::annealing         0.2       simulation tools
            	simulation::montecarlo        0.1       
            	simulation::random            0.1       
------          -------                 -----------     -----------------------
stringprep  	stringprep                    1.0.0     preparation for
            	stringprep::data              1.0.0     internationalized
            	unicode                       1.0.0     strings
            	unicode::data                 1.0.0     
------          -------                 -----------     -----------------------
struct         	struct::disjointset           1.0       union-merge structure
------          -------                 -----------     -----------------------
yaml        	huddle                        0.1.3     generic serialization format
            	yaml                          0.3.3     YAML processing
------          -------                 -----------     -----------------------

Changes from Tcllib 1.10 to 1.11
================================

Legend  Change  Details Comments
        Major   API:    ** incompatible ** API changes.

        Minor   EF :    Extended functionality, API.
                I  :    Major rewrite, but no API change

        Patch   B  :    Bug fixes.
                EX :    New examples.
                P  :    Performance enhancement.

        None    T  :    Testsuite changes.
                D  :    Documentation updates.

                                Tcllib 1.10     Tcllib 1.11
Module          Package         Old version     New Version     Comments
------          -------         -----------     -----------     ---------------
aes         	aes                   1.0.0    	1.0.1   	B, D, T
asn         	asn                   0.8.1    	0.8.3   	B, D
base64      	base64                2.3.2    	2.4     	Changed defaults, B, D
bench       	bench                 0.3.1    	0.4		I
blowfish    	blowfish              1.0.3    	1.0.4   	T
cmdline     	cmdline                 1.3    	1.3.1   	B, D
comm        	comm                  4.5.6    	4.5.7   	B, D
crc         	cksum                 1.1.1    	1.1.2   	B, D
csv         	csv                     0.7    	0.7.1     	B
dns         	spf                   1.1.0    	1.1.1   	B
doctools    	doctools                1.3    	1.3.5   	B
            	doctools::changelog   0.1.1    	1       	Accept maturity
            	doctools::cvs         0.1.1    	1       	.
            	doctools::idx           0.3    	1       	.
            	doctools::toc           0.3    	1       	.
fileutil    	fileutil             1.13.3   	1.13.4  	B
            	fileutil::multi::op     0.5    	0.5.2   	B
            	fileutil::traverse      0.3    	0.4     	B
ftp         	ftp                   2.4.8    	2.4.9   	B, D
            	ftp::geturl             0.2    	0.2.1   	B
ftpd        	ftpd                  1.2.3    	1.2.4   	B
grammar_fa  	grammar::fa::op         0.4    	0.4.1   	B
htmlparse   	htmlparse             1.1.2    	1.1.3   	B, D
http        	autoproxy             1.4      	1.5.1   	I, B, D
inifile     	inifile               0.2.1    	0.2.3   	I, B, D
irc         	irc                     0.6    	0.6.1   	B, D
jpeg        	jpeg                    0.3    	0.3.3   	D, B, T
ldap        	ldap                  1.6.8    	1.7     	EF, B
log         	log                     1.2    	1.2.1     	B, D
math        	math::bigfloat        1.2.1    	1.2.2   	B
            	math::bigfloat          2.0    	2.0.1   	B
            	math::calculus          0.7    	0.7.1     	B
            	math::linearalgebra   1.0.2    	1.0.3   	B, T
            	math::special         0.2.1    	0.2.2   	B
            	math::statistics        0.5    	0.6     	EF, D, T
md4         	md4                   1.0.4    	1.0.5   	B
md5         	md5                   2.0.5    	2.0.7   	B
md5crypt    	md5crypt              1.0.0    	1.1.0   	EF
mime        	mime                  1.5.2    	1.5.4   	B
            	smtp                  1.4.4    	1.4.5   	B
nmea        	nmea                  0.1.1    	0.2.0   	EF, B, D
nns         	nameserv                0.3    	0.4.1   	B, D
            	nameserv::auto          0.1    	0.3     	I, B, D
            	nameserv::server        0.3    	0.3.2   	I, B, D
pluginmgr   	pluginmgr               0.1    	0.2     	B, D
sasl        	SASL                  1.3.1    	1.3.2   	B
struct         	struct::graph           2.2     2.3     	EF, T
	      	struct::list          1.6.1    	1.7     	B, T, EF
            	struct::matrix        2.0.1    	2.0.2   	B
            	struct::prioqueue     1.3.1    	1.4     	EF
            	struct::queue           1.4     1.4.1   	I, D
            	struct::set           2.2.1    	2.2.3   	B, T
            	struct::stack         1.3.1    	1.3.3   	P, T, I, D
term	   	term::ansi::code::ctrl  0.1	0.1.1		B, D
textutil    	textutil::string        0.7     0.7.1   	P, D
tie         	tie::std::file        1.0.2    	1.0.4   	B, D
tiff        	tiff                    0.1     0.2.1   	B, T, D
transfer    	transfer::copy          0.1     0.2     	B
uev         	uevent                0.1.2    	0.2     	EF, B
wip         	wip                     1.0     1.1.1   	EF, B
            	wip                     2.0     2.1.1   	EF, B
------          -------         -----------     -----------     ---------------


Invisible or no changes
------          -------         -----------     -----------     ---------------
base32      	base32                          0.1     	T, D
            	base32::core                    0.1     	T, D
            	base32::hex                     0.1     	T, D
base64      	uuencode                        1.1.4   	D
            	yencode                         1.1.1		D
bee         	bee                             0.1     	D
bench       	bench::in                       0.1     
            	bench::out::csv                 0.1.2   
            	bench::out::text                0.1.2   
bibtex      	bibtex                          0.5     	D
calendar    	calendar                        0.2  
control     	control                         0.1.3
counter     	counter                         2.0.4
crc         	crc16                           1.1.1   	D
            	crc32                           1.3     	D
            	sum                             1.1.0   	D
des         	des                             1.1.0
dns         	dns                             1.3.2   
            	ip                              1.1.2   
            	resolv                          1.0.3   
docstrip    	docstrip                        1.2  
            	docstrip::util                  1.2  
exif        	exif                            1.1.2   	D
fileutil    	fileutil::multi                 0.1     	D
fumagic     	fileutil::magic::cfront         1.0     	D
            	fileutil::magic::cgen           1.0     	D
            	fileutil::magic::filetype       1.0.2   	D
            	fileutil::magic::mimetype       1.0.2   	D
            	fileutil::magic::rt             1.0     	D
grammar_fa  	grammar::fa                     0.3     
            	grammar::fa::dacceptor          0.1.1   
            	grammar::fa::dexec              0.2     
grammar_me  	grammar::me::cpu                0.2     	D
            	grammar::me::cpu::core          0.2     	D
            	grammar::me::cpu::gasm          0.1     	D
            	grammar::me::tcl                0.1     	D
            	grammar::me::util               0.1     	D
grammar_peg 	grammar::peg                    0.1     	D
            	grammar::peg::interp            0.1     	D
html        	html                            1.4  
ident       	ident                           0.42    	D
interp      	interp                          0.1.1
            	interp::delegate::method        0.2  
            	interp::delegate::proc          0.2  
javascript  	javascript                      1.0.2
json        	json                            1.0     	D, T
ldap        	ldapx                           1.0     	D
log         	logger                          0.8     
            	logger::appender                1.3     
            	logger::utils                   1.3     
mapproj     	mapproj                         1.0  
math        	math                            1.2.4   
            	math::bignum                    3.1.1   
            	math::complexnumbers            1.0.2   
            	math::constants                 1.0.1		T
            	math::fourier                   1.0.2   
            	math::fuzzy                     0.2     
            	math::geometry                  1.0.3   
            	math::interpolate               1.0.2   
            	math::optimize                  1.0     
            	math::polynomials               1.0.1   
            	math::rationalfunctions         1.0.1   
            	math::roman                     1.0		D
md5         	md5                             1.4.4
multiplexer 	multiplexer                     0.2  
ncgi        	ncgi                            1.3.2   	D
nns         	nameserv::common                0.1     	
nntp        	nntp                            0.2.1
ntp         	time                            1.2.1
otp         	otp                             1.0.0
page        	page::analysis::peg::emodes     0.1  
            	page::analysis::peg::minimize   0.1  
            	page::analysis::peg::reachable  0.1  
            	page::analysis::peg::realizable 0.1  
            	page::compiler::peg::mecpu      0.1.1
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
            	pop3d::dbox                     1.0.2
png         	png                             0.1.2   	D
pop3d       	pop3d                           1.1.0
            	pop3d::udb                      1.1  
pop3        	pop3                            1.6.3
profiler    	profiler                        0.3  
rc4         	rc4                             1.1.0
rcs         	rcs                             0.1     	D
report      	report                          0.3.1
ripemd      	ripemd128                       1.0.3
            	ripemd160                       1.0.3
sasl        	SASL::NTLM                      1.1.1
            	SASL::XGoogleToken              1.0.1
sha1        	sha1                            1.1.0   	D
            	sha1                            2.0.3   	D
            	sha256                          1.0.2   	D
smtpd       	smtpd                           1.4.0
snit        	snit                            1.3.1   	D, T
            	snit                            2.2.1   	D, T
soundex     	soundex                         1.0     	D
stooop      	stooop                          4.4.1
            	switched                        2.2.1
            	tclDES                          1.0.0
            	tclDESjr                        1.0.0
struct      	struct                          1.4     	
            	struct                          2.1     	
            	struct::graph                   1.2.1   	
            	struct::matrix                  1.2.1   	
            	struct::pool                    1.2.1   	
            	struct::record                  1.2.1   	
            	struct::skiplist                1.3     	
            	struct::tree                    1.2.2   	
            	struct::tree                    2.1.1   	T
tar         	tar                             0.4     	D
term        	term                            0.1     	D
            	term::interact::menu            0.1     	D
            	term::interact::pager           0.1     	D
            	term::receive                   0.1     	D
            	term::receive::bind             0.1     	D
            	term::send                      0.1     	D
textutil    	textutil                        0.7.1   	D
            	textutil::adjust                0.7     	D
            	textutil::expander              1.3.1   	D
            	textutil::repeat                0.7     	D
            	textutil::split                 0.7     	D
            	textutil::tabify                0.7     	D
            	textutil::trim                  0.7     	D
tie         	tie                             1.1
            	tie::std::array                 1.0		D
            	tie::std::dsource               1.0		D
            	tie::std::growfile              1.0		D
            	tie::std::log                   1.0		D
            	tie::std::rarray                1.0		D
transfer    	transfer::connect               0.1     	
            	transfer::copy::queue           0.1     	
            	transfer::data::destination     0.1     	
            	transfer::data::source          0.1     	
            	transfer::receiver              0.1     	
            	transfer::transmitter           0.1     	
treeql      	treeql                          1.3.1
units       	units                           2.1     	D
uri         	uri                             1.2.1   	
            	uri::urn                        1.0.2   	D
uuid        	uuid                            1.0.1
------          -------         -----------     -----------     ---------------
