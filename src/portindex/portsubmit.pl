#!/usr/bin/perl -w
#
# Copyright (c) 2003-2004 Apple Computer, Inc.
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
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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
# 20-Dec-2003
# Kevin Van Vechten <kvv@opendarwin.org>
#

#####
#
# portsubmit.cgi
# Accepts new ports for submission into the index.
#
#####

# The following tree should be accessible to the cgi.
# cgi-bin/
#     portsubmit.cgi
#     portregister.cgi
#     .portpasswd
# ports/
#     index/
#         .last_transaction
#         initialize.sql
#         portindex-1.sql
#         portindex-2.sql
#         ...
#     files/
#         $name/
#             $version/
#                 .last_revision
#                 $revision/
#                     Portfile.tar.gz
#                 ...
#             ...
#         ...
#

my $htdocs = "/Library/WebServer/Documents";
my $portfiles = "$htdocs/ports/files";
my $portindex = "$htdocs/ports/index";
my $portpasswd = "$htdocs/ports/index/.portpasswd";

use CGI;
use Fcntl;
use Digest::MD5 qw(md5_hex);
my $cgi = new CGI;

#
# These are the variables expected from the CGI client.
#

my $name = $cgi->param('name');
$name =~ s/[^A-Za-z0-9_.-]//g;
my $version = $cgi->param('version');
$version =~ s/[^A-Za-z0-9_.-]//g;
my $md5 = $cgi->param('md5');
$md5 =~ s/[^A-Fa-f0-9]//g;
my $submitted_by = $cgi->param('submitted_by');
$submitted_by =~ s/[^A-Za-z0-9.!@#$%^&*_+=-]//g;
my $password = md5_hex($cgi->param('password'));
my $comment = $cgi->param('comment');
$comment =~ s/[^A-Za-z0-9 '",.!@#$%^&*_+=-]//g; #'
$comment =~ s/'/\\'/g;
$comment =~ s/"/\\"/g;
my @maintainers = split(':', $cgi->param('maintainers'));
my @categories = split(':', $cgi->param('categories'));


#
# The atomic_serial subroutine atomically (from the
# perspective of portindex.cgi processes) reads the
# most recently allocated integer from the specified
# file (argument to this sub), increments it, writes
# the value back out to the file, and returns the
# value to the caller.
#
sub atomic_serial($) {
    my ($filename) = @_;
    sysopen(SERIAL, $filename, O_RDWR|O_CREAT|O_EXLOCK) or die "Unable to open $filename: $!";
    my $serial = <SERIAL>;
    if (!$serial) {
        $serial = "1";
    } else {
        $serial = $serial + 1;
    }
    # serials are monotonically increasing, so simply
    # over-writing the previous contents should be OK.
    seek(SERIAL, 0, 0);
    print SERIAL "$serial\n";
    print SERIAL "# DO NOT EDIT.\n";
    close(SERIAL);
    return $serial;
}

#
# This is almost the same as the atomic_serial sub
# except it uses the serial to name the portindex
# file to be appended/created.  Unfortunately this
# couldn't use the atomic_serial sub because of
# atomicity constraints.  We need to keep the serial
# locked during our open/create/open flailing.
#
sub atomic_index($) {
    my ($path) = @_;
    sysopen(SERIAL, "$path/.last_index", O_RDWR|O_CREAT|O_EXLOCK) or die "Unable to open $path/.last_index: $!";
    my $serial = <SERIAL>;
    if (!$serial) {
        $serial = "1";
    } else {
        chomp($serial);
    }
    
    sysopen(PORTINDEX, "$path/portindex-$serial.sql", O_WRONLY|O_APPEND|O_CREAT|O_EXLOCK) or die "Unable to open portindex-$serial.sql: $!";
    my $size = (stat(PORTINDEX))[7];
    # If the index file is greater than 1MB in size, rotate to the next one.
    if ($size > 1024*1024) {
        $serial = $serial + 1;
        close(PORTINDEX);
        sysopen(PORTINDEX, "$path/portindex-$serial.sql", O_WRONLY|O_APPEND|O_CREAT|O_EXLOCK) or die "Unable to open portindex-$serial.sql: $!";
    }
    # serials are monotonically increasing, so simply
    # over-writing the previous contents should be OK.
    seek(SERIAL, 0, 0);
    print SERIAL "$serial\n";
    print SERIAL "# DO NOT EDIT.\n";
    close(SERIAL);
    return PORTINDEX;
}

#####
#
# Here lies the real processing
#
#####

# We output in text/plain mode for easy parsing of the
# result by the client.
print $cgi->header('text/plain');

# Verify the submitter / password.
my $authenticated = 0;
sysopen(PASSWD, "$portpasswd", O_RDONLY) or die "Unable to open $portpasswd: $!";
while (<PASSWD>) {
    my ($email, $hash) = split(':', $_);
    if ($email eq $submitted_by) {
        if ($hash eq $password) {
            $authenticated = 1;
            last;
        }
    }
}

if (!$authenticated) {
    print "ERROR: Invalid username or password.\n";
    exit 0;
}

# Start by obtaining a unique identifier for this transaction.

my $transaction = &atomic_serial("$portindex/.last_transaction");

# 
# Create a destination directory for the new revision of the specified port.
#

my $dir = "$portfiles/$name/$version";
chdir("/");
foreach my $d (split('/', $dir)) {
    if ($d) {
        print STDERR "$d\n";
        if (!mkdir($d)) {
            die "Unable to mkdir: $!" if $! != 17; # EEXIST
        }
        chdir($d) or die "Unable to chdir: $!";
    }
}
$revision = &atomic_serial(".last_revision");

mkdir("$revision");
chdir("$revision");

#
# Copy the attachment to the destination
#

$filename = $cgi->param('attachment');
sysopen(ATTACHMENT, "$filename", O_WRONLY|O_CREAT|O_EXLOCK) or die "Unable to open $filename: $!";
while (<$filename>) {
    print ATTACHMENT;
}
close(ATTACHMENT);

#
# Print the transaction out to the SQL logs
#

$handle = &atomic_index($portindex);

print $handle "-- BEGIN TRANSACTION #$transaction\n";
print $handle "INSERT INTO ports (pid, name, version, revision) VALUES ('$transaction', '$name', '$version', '$revision');\n";
print $handle "INSERT INTO keywords (pid,keyword,value) VALUES ('$transaction','submitter','$submitted_by');\n";
print $handle "INSERT INTO keywords (pid,keyword,value) VALUES ('$transaction','commit_log','$comment');\n";
foreach my $maintainer (@maintainers) {
    chomp($maintainer);
    $maintainer =~ s/[^A-Za-z0-9.!@#$%^&*_+=-]//g;
    print $handle "INSERT INTO keywords (pid,keyword,value) VALUES ('$transaction','maintainer','$maintainer');\n";
}
foreach my $category (@categories) {
    chomp($category);
    $category =~ s/[^A-Za-z0-9_.-]//g;
    print $handle "INSERT INTO keywords (pid,keyword,value) VALUES ('$transaction','category','$category');\n";
}
print $handle "-- END TRANSACTION #$transaction\n";

close($handle);

#
# Report normal, successful, completion.
#

print "OK: $transaction\n";
