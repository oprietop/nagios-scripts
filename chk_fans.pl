#!/usr/bin/perl -w
# Retrieves and parses the Fan Status output from a securestack switch.

use strict;
use Net::Telnet;

print "$0 <IP>\n" and exit 3 unless $#ARGV == 0 and $ARGV[0] =~ /^(\d{1,3}\.){3}\d{1,3}$/;

my $telnet = new Net::Telnet ( Timeout  => 5
                             , Errmode  => 'return'
                             , Prompt   => '/\(rw\)->/i'
                             );
$telnet->open($ARGV[0]);
$telnet->login('USER', 'PASS');
$telnet->cmd('set length 0');
my $result = join('', $telnet->cmd('show system'));
$result =~ s/([\s-])+/$1/g;
print "Null output!\n" and exit 1 unless $result;

my $err=0;
while ($result =~ /Switch\s(\d+).+?Fan2-Status\n((?:Ok|Not.+?))\s((?:Ok|Not.+?))\n/sg) {
    $err++ if "$2$3" ne "OkOk";
    print "SW$1(Fan1:$2 Fan2:$3) ";
}
print "NOK!\n" and exit 1 if $err or print "OK!\n" and exit 0;
