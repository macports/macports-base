# mail-test.pl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sf.net>
#
# Send some mail from Perl.
#
# This sends two messages, one valid and one without a recipient using the
# SMTP protocol.
#
# usage: ./mail-test.pl smtpd-host ?smtpd-port?
#
# -------------------------------------------------------------------------

use diagnostics;
use strict;

use Net::SMTP;
use Sys::Hostname;

my ($smtp_smart_host, $smtp_smart_port) = (shift, shift);

$smtp_smart_host = 'localhost' if (!$smtp_smart_host);
$smtp_smart_port = 25 if (!$smtp_smart_port);

my $smtp_default_from = 'postmaster@' . hostname();
my $smtp_timeout = 120;
my $smtp_log_mail = 0;
my $smtp_debug = 1;

my $sender_address = 'perl-test-script@' . hostname() . '';
my $recipient_address = 'tcl-smtpd@' . $smtp_smart_host . '';
my $from_address = 'Perl Test Script <perl-test-script@' . hostname() . '>';
my $ro_address = 'Tcl Server <tcl-smtpd@' . $smtp_smart_host . '>';

print "Sending valid message\n";
test_ok();
print "Sending invalid message\n";
test_no_rcpt();

sub test_no_rcpt {
  my $header = 'From: ' . $sender_address . "\n";
  $header .= 'Subject: perl test' . "\n";
  my $message = <<EOF;
This is a sample message in no particular format, sent by Perl's
Net::SMTP package.
Let's check the transparency code with a sentance ending on the next line
. Like this!
EOF

  Sendmail($header . "\n" . $message . "\n");
}

sub test_ok {
  my $header = 'From: ' . $sender_address . "\n";
  $header .= 'To: ' . $recipient_address . "\n";
  $header .= 'Subject: perl test' . "\n";
  my $message = <<EOF;
This is a sample message in no particular format, sent by Perl's
Net::SMTP package.
Let's check the transparency code with a sentance ending on the next line
. Like this!
EOF

  Sendmail($header . "\n" . $message . "\n");
}

# -------------------------------------------------------------------------
# Sendmail replacement (replaces exec'ing /usr/lib/sendmail...)
#
# Just call this function with the entire mail (headers and body together).
# The recipient and sender addresses are extracted from the mail text.
# -------------------------------------------------------------------------

sub Sendmail {
    my ($msg) = (@_);
    my @rcpts = ();
    my $from = $smtp_default_from;
    
    # Process the message headers to identify the recipient list.
    my @msg = split(/^$/m, $msg);
    my $header = $msg[0];
    $header =~ s/\n\s+/ /g;  # fix continuation lines
    
    my @lines = split(/^/m, $header);
    chomp(@lines);
    foreach my $line (@lines) {
        my ($key, $value) = split(/:\s*/, $line, 2);
        if ($key =~ /To|CC|BCC/i ) {
            push(@rcpts, $value);
        }
        if ($key =~ /From/i) {
            $from = $value;
        }
    }
    
    my $smtp = Net::SMTP->new($smtp_smart_host,
                              Hello => hostname(),
                              Port  => $smtp_smart_port,
                              Timeout => $smtp_timeout,
                              Debug => $smtp_debug)
        || die "SMTP failed to connect: $!";

    $smtp->mail($from, (Size=>length($msg), Bits=>'8'));
    $smtp->to(@rcpts);
    if ($smtp->data()) {        # start sending data;
      $smtp->datasend($msg);    # send the message
      $smtp->dataend();         # finished sending data
    } else {
      $smtp->reset();
    }
    $smtp->quit;                # end of session

    if ( $smtp_log_mail ) {
        if ( open(MAILLOG, ">> data/maillog") ) {
            print MAILLOG "From $from at ", localtime() . "\n";
            print MAILLOG "To: " . join(@rcpts, ',') . "\n";
            print MAILLOG $msg . "\n\n";
            close(MAILLOG);
        }
    }
}

# -------------------------------------------------------------------------
