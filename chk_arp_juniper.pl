#!/usr/bin/perl -w
use strict;
use Net::Telnet;
print "$0 <IP>\n" and exit 3 unless $#ARGV == 0 and $ARGV[0] =~ /^(\d{1,3}\.){3}\d{1,3}$/;
my %vlans = ( 111 => 'Vlan 111)'
            , 222 => 'Vlan 222)'
            , 333 => 'Vlan 333)'
            );
my $telnet = new Net::Telnet ( Timeout  => 5
                             , Errmode  => 'return'
                             , Prompt   => '/rw@.+?/i'
                             );
$telnet->open($ARGV[0]);
$telnet->login('XXX', 'XXXXXXXXX');
$telnet->cmd('set cli screen-length 0');
my $arp = join('', $telnet->cmd("show arp no-resolve"));
my $instances = join('', $telnet->cmd("show route instance detail"));
$instances =~ s/ //g;
my %vlan_vr = ();
while ($instances =~ /Interfaces:\n(.+?)Tables:\n(\w+)/sg) {
    my $interfaces = $1;
    my $inst = $2;
    while ($interfaces =~ /vlan\.(\d+)/sg) {
        $vlan_vr{$1} = $inst;
    }
}
my $keys = join ('|',keys %vlans);
while ($arp =~ /((?:\d{1,3}\.){3}\d{1,3})\s+vlan.($keys)\s+/sg) {
    print "$1\t($2) $vlans{$2}\t";
    my $ping = join('', $telnet->cmd("ping routing-instance $vlan_vr{$2} count 1 wait 2 $1"));
    while ($ping =~ /(\d+)% packet loss/sg) {
        $1 ? print "NOK!\n" : print "OK\n";
    }
}
exit 0;
