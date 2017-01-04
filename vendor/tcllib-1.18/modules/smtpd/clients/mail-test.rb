require 'net/smtp'

sndr = 'ruby-test-script@localhost'
rcpt = 'tcllib-test@localhost'
msg = 'From: Ruby <ruby-test-script@localhost>
To: SMTPD <tcllib-test@localhost>
Subject: Testing from Ruby

This is a sample message send from Ruby.
As always, let us check the transparency function:
. <-- there should be a dot there.
Bye'

Net::SMTP.start('localhost', 25) do |smtp|
  smtp.send_mail msg, sndr, rcpt
end
