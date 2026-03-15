# Python mail sample

import sys, smtplib


class SMTPTest:
    def __init__(self, interface='localhost', port=25):
        self.svr = smtplib.SMTP(interface, port)
        self.svr.set_debuglevel(1)

    def sendmail(self, sender, recipient, message):
        try:
            self.svr.sendmail(sender, recipient, message)
        except:
            print "oops"

    def quit(self):
        self.svr.quit()

def test():
    sndr = "python-script-test@localhost"
    rcpt = "tcllib-test@localhost"
    mesg = """From: Python Mailer <python-script@localhost>
To: Tcllib Tester <tcllib-test@localhost>
Date: Fri Dec 20 14:20:49 2002
Subject: test from python

This is a sample message from Python.
Hope it's OK
Check transparency:
. <- there should be one dot here.
Done
"""
    # Connect
    svr = SMTPTest('localhost')

    # Try normal message
    svr.sendmail(sndr, rcpt, mesg)
    
    # should fail: invalid recipient.
    svr.sendmail(sndr, "", mesg)
    
    # should fail: NULL recipient only valid for sender
    svr.sendmail(sndr, "<>", mesg)

    # should be ok: null sender (permitted for daemon responses)
    svr.sendmail("<>", rcpt, mesg)

    svr.quit()


if __name__ == '__main__':
    test()
