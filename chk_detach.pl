#!/usr/bin/perl -w
# Chech members with Detached ports on a securestack stack.

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

my @result = $telnet->cmd('show port status');
print "Null output!\n" and exit 1 unless @result;
chomp @result;

my %hash=();
map {$hash{$1} = 1 if /^[fg]e\.(\d)\.\d+\s+Detach\s/} @result;

if (scalar keys %hash) {
    print "NOK! Hay ".(scalar keys %hash)." switch/es con puertos Detach: ".join(', ', sort keys %hash)."\n";
    exit 1;
} else {
    print "OK!\n";
    exit 0;
}
