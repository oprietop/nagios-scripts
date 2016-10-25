#!/usr/bin/perl -w
# Retrieves and parses the Switch Status output from a securestack switch.

use strict;
use Net::Telnet;

print "$0 <IP>\n" and exit 3 unless $#ARGV == 0 and $ARGV[0] =~ /^(\d{1,3}\.){3}\d{1,3}$/;

my $telnet = new Net::Telnet ( Timeout  => 5
                             , Errmode  => 'return'
                             , Prompt   => '/\(rw\)->/i'
                             );
$telnet->open($ARGV[0]);
$telnet->login('USER', 'PASSWORD');
$telnet->cmd('set length 0');
my @result = grep { /^\d/ and s/([\s-])+/$1/g } $telnet->cmd('show switch status');
chomp @result;
print "Null output!\n" and exit 1 unless @result;
my @nok = grep { s/^([1-8]).*/$1/g } grep { !/Full Enable Enable/ } @result;
print "NOK! Problemas en ".($#nok+1)." de ".($#result+1)." elemento/s: ".join(",", @nok) and exit 2 if @nok;
print "OK! (".($#result+1)." elemento/s)" and exit 0;
