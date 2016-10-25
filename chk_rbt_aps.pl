#!/usr/bin/perl -w

use strict;
use Net::Telnet;

my $telnet = new Net::Telnet ( Timeout  => 5
                             , Errmode  => 'die'
                             , Prompt   => '/RBT.+[>#]/i'
                             );
$telnet->open('xxx.xxx.xxx.xxx');
$telnet->login('xxxxx', 'xxxxx');
$telnet->print('enable');
$telnet->waitfor('/Enter password:/i');
$telnet->cmd('+salsitxa');
$telnet->cmd('set length 0');
my @data = $telnet->cmd('show ap status all name');

print "Bad Data" and exit 1 if $#data < 7;  # El header ya ocupa 8 filas.

my (@ApOK, @ApFail) = ();
foreach (@data) {
    next if not /^\s{0,3}\d{1,4}/ or /^999\d/;
    my $ApName  = substr($_, 5,  16);
    my $Uptime  = substr($_, 72, 6);
    if ( not $ApName =~ /^<unknown>/ and $Uptime =~ /^\s+$/ ) {
        $ApName =~ s/\s+$//g;
        push (@ApFail, $ApName);
    }
    push (@ApOK, $ApName);
}

if ($#ApFail == -1) {
    print "OK, $#ApOK APs.\n" and exit 0; # OK
    } else {
    print "(".($#ApFail+1)." APs down) ".join ( ", ", @ApFail)."\n" and exit 1;
}
