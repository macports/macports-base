#!/usr/bin/perl

die("I only understand docbook\n") unless @ARGV && $ARGV[0] eq 'docbook';

#my $ii = '//';
#my $io = '//';

#my $si = '**';
#my $so = '**';

my $ii = '<emphasis>';
my $io = '</emphasis>';

my $si = '<emphasis role="strong">';
my $so = '</emphasis>';

while(<STDIN>) {
  chomp;
  my $in = '';
  my $out = '';
  s/^\s+//;
  s/\s+$//;
  if (/^(.*)(\s*\/\*.*?\*\/\s*?)$/) {
    $out = $2;
    $_ = $1;
  }
  if (/^(my\s+)(.*?)$/) {
    $in = $1;
    $_ = $2;
  }
  if (/(?<!\&gt);$/) {
    $out = ";$out";
    chop $_;
  }
  if (!/^[a-zA-Z0-9_]+$/) {
    $_ = " $_";
    $_ = "$_ ";
    s/(?<=[^a-zA-Z_\&:\.\'\";])(?!solv\W|Solv\W|Pool\W)([\$\@a-zA-Z_][a-zA-Z0-9_]*)(?=[^a-zA-Z0-9_\(;\[])(?!::)(?! [^=])/<-S><I>$1<-I><S>/g;
    # fixup for perl bare words
    s/{<-S><I>([a-zA-Z_][a-zA-Z0-9]*)<-I><S>}/{$1}/g;
    # fixup for callbackfunctions
    s/\\(&amp;[a-zA-Z_]+)/\\<-S><I>$1<-I><S>/;
    # fixup for stringification
    s/\$<-S><I>/<-S><I>\$/g;
    # fixup for %d
    s/%<-S><I>d<-I><S>\"/%d\"/;
    s/%<-S><I>d<-I><S>\\<-S><I>n<-I><S>/%d\\n/;
    # iterators
    s/^ //;
    s/ $//;
    s/^(for (?:my )?)(\S+) /$1<-S><I>$2<-I><S> /;
  }
  $_ = "<S>$_<-S>";
  s/<S>(\s*)<-S>/$1/g;
  s/<-S>(\s*)<S>/$1/g;
  s/<I>(\s*)<-I>/$1/g;
  s/<-I>(\s*)<I>/$1/g;
  s/<S>(\s+)/$1<S>/g;
  s/(\s+)<-S>/<-S>$1/g;
  s/<I>(\s+)/$1<I>/g;
  s/(\s+)<-I>/<-I>$1/g;
  s/<S>/$si/g;
  s/<-S>/$so/g;
  s/<I>/$ii/g;
  s/<-I>/$io/g;
  print "$in$_$out\n";
}
