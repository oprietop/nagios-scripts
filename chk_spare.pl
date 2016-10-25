#!/usr/bin/perl -w
# Chech a securestack stack for spare members (48 fe free ports).

use strict;
use Net::Telnet;

print "$0 <IP>\n" and exit 3 unless $#ARGV == 0 and $ARGV[0] =~ /^(\d{1,3}\.){3}\d{1,3}$/;

my $telnet = new Net::Telnet ( Timeout  => 5
                             , Errmode  => 'return'
                             , Prompt   => '/\(rw\)->/i'
                             );
$telnet->open($ARGV[0]);
$telnet->login('XXXX', 'XXXXXXXX');
$telnet->cmd('set length 0');

my @result = $telnet->cmd('show port status');
print "Null output!\n" and exit 1 unless @result;
chomp @result;

my %hash = ();
my $count = 0;
my $swnum = 0;

foreach (@result) {
    if (/^fe\.(\d)\.\d+\s+Down\s/) {
        $swnum = $1;
        $count++;
        $hash{$swnum} = 1 if $count == 48;
    } else {
        $count = 0;
    }
}

$swnum = $1;

if (scalar keys %hash or $swnum < 3) {
    print "OK! Found ".(scalar keys %hash)." spare element/s in the stack: ".join(', ', sort keys %hash)." from     a total of $swnum elements.\n";
    exit 1;
} else {
    print "NOK! No spare elements in a $swnum elements stack\n";
    exit 0;
}
