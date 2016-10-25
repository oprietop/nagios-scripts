#!/usr/bin/perl -w
use strict;
use Net::Telnet;
print "$0 <IP>\n" and exit 3 unless $#ARGV == 0 and $ARGV[0] =~ /^(\d{1,3}\.){3}\d{1,3}$/;
my %vlans = ( 111 => 'Vlan 111'
            , 222 => 'Vlan 222'
            , 333 => 'Vlan 333'
            );
my $telnet = new Net::Telnet ( Timeout  => 5
                             , Errmode  => 'return'
                             , Prompt   => '/.*\(rw\)->/i'
                             );
$telnet->open($ARGV[0]);
$telnet->login('XXX', 'XXXXXXXX');
$telnet->cmd('router');
my $result = join('', $telnet->cmd("show ip arp"));
my $keys = join ('|',keys %vlans);
while ($result =~ /((?:\d{1,3}\.){3}\d{1,3})\s+[\w\s\:]+Vlan($keys)/sg) {
    print "$1\t($2) $vlans{$2}\t";
    my $ping = join('', $telnet->cmd("ping $1"));
    $ping =~ /is alive/ ? print "OK\n" : print "NOK!\n";
}
exit 0;
