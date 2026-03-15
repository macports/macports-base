<?
  # Send a message from PHP (check the php.ini for the 
  # server, port and default sender details)

  $sndr = 'php-test-script@localhost';
  $rcpt = 'tcllib-test@localhost';

  $subject = "Testing from PHP";

  $hdrs  = "MIME-Version: 1.0\r\n";
  $hdrs .= "Content-type: text/plain; charset=iso-8859-1\r\n";
  $hdrs .= "From: PHP Script <" . $sndr . ">";

  $body  = "This is a sample message send from PHP.\r\n";
  $body .= "As always, let us check the transparency function:\r\n";
  $body .= ". <-- there should be a dot there.\r\n";
  $body .= "Bye";

  mail($rcpt, $subject, $body, $hdrs);

?>
