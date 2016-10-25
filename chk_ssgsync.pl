#!/usr/bin/perl -w
# Script para checkear la sincronía en un cluster SSG-550M
use strict;
use Net::Telnet;
print "$0 <IP> <PASS>\n" and exit 3 unless $#ARGV == 1 and $ARGV[0] =~ /^(\d{1,3}\.){3}\d{1,3}$/ and $ARGV[1] =~ /^\w+$/;
my $telnet = new Net::Telnet ( Timeout => 15
                             , Errmode => 'return'
                             , Prompt  => '/.*\(\w\)->/i'
                             );
$telnet->open($ARGV[0]);
$telnet->login('admin', $ARGV[1]);
$telnet->cmd('set console page 0');
$telnet->print('exec nsrp sync global-config check-sum');
$telnet->waitfor('/configuration/i');
my $out = $telnet->lastline;
print "No response from $ARGV[0]\n" and exit 1 unless $out;
print $out and exit 0 if $out =~ /configuration in sync/;
print $out and exit 1;
