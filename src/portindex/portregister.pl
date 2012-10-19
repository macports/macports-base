#!/usr/bin/perl -w
#
# Copyright (c) 2003-2004 Apple Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#
# 7-Feb-2004
# Kevin Van Vechten <kvv@opendarwin.org>
#

#####
#
# portregister.cgi
# Register a new committer with the index
#
#####

my $PREFIX = "@@PREFIX@@";
my $portpasswd = "$PREFIX/index/.portpasswd";

use CGI;
use Fcntl;
use Digest::MD5 qw(md5_hex);
my $cgi = new CGI;

#
# These are the variables expected from the CGI client.
#

my $email = $cgi->param('email');
my $password = md5_hex($cgi->param('password'));
my $fullname = $cgi->param('fullname');

$email =~ s/[^A-Za-z0-9.!@#$%^&*_+=-]//g;
$fullname =~ s/[^A-Za-z0-9 ',.!@#$%^&*_+=-]//g; #'


sysopen(PASSWD, $portpasswd, O_WRONLY|O_APPEND|O_CREAT) or die "Unable to open $portpasswd: $!";
print PASSWD "$email:$password:$fullname\n";
close(PASSWD);

print $cgi->header();
print $cgi->start_html();
print "Thank you.";
print $cgi->end_html();
