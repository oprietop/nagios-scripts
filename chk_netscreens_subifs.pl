#!/usr/bin/perl -w
# http://search.cpan.org/src/HARDAKER/SNMP-5.0401/t/bulkwalk.t
# Proper subif traddic stats for a SSG firewall
# Filename example: snmp_firewalls_firew2_subifs

use strict;
use SNMP;

my $config = 1 if $ARGV[0] and lc($ARGV[0]) eq "config";

my %params = ( community => $ENV{community} || 'public'
             , version   => '2'
             );

if ($0 =~ /snmp_([^_]+)_([^_]+)_(subifs)$/) {
    $params{group} = $1;
    $params{host}  = $2;
    $params{type}  = $3 || 'subifs';
} else {
    die "regex phail!\n"
}

my %oids = ( '.1.3.6.1.4.1.3224.9.3.1.1'   => { 'DESC' => 'Index'
                                              , 'OID'  => 'nsIfFlowIfIdx'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.4.1.3224.9.1.1.2'   => { 'DESC' => 'IfName'
                                              , 'OID'  => 'nsIfName'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.4.1.3224.9.1.1.5'   => { 'DESC' => 'IfStatus'
                                              , 'OID'  => 'nsIfStatus'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.4.1.3224.9.3.1.3'   => { 'DESC' => 'Bytes In'
                                              , 'OID'  => 'nsIfFlowInByte'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.4.1.3224.9.3.1.5'   => { 'DESC' => 'Bytes Out'
                                              , 'OID'  => 'nsIfFlowOutByte'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.2.1.2.2.1.14'       => { 'DESC' => 'Errors In'
                                              , 'OID'  => 'ifInErrors'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.2.1.2.2.1.20'       => { 'DESC' => 'Errors Out'
                                              , 'OID'  => 'ifOutErrors'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.2.1.2.2.1.13'       => { 'DESC' => 'Drop In'
                                              , 'OID'  => 'ifInDiscards'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.2.1.2.2.1.19'       => { 'DESC' => 'Drop Out'
                                              , 'OID'  => 'ifOutDiscards'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.4.1.3224.8.1.1.1.1' => { 'DESC' => 'Zone Id'
                                              , 'OID'  => 'nsZoneCfgId'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.4.1.3224.8.1.1.1.2' => { 'DESC' => 'Zone Name'
                                              , 'OID'  => 'nsZoneCfgName'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.4.1.3224.9.1.1.4'   => { 'DESC' => 'ifZone'
                                              , 'OID'  => 'nsIfZone'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.4.1.3224.9.1.1.6'   => { 'DESC' => 'Zone IP'
                                              , 'OID'  => 'nsIfIp'
                                              , 'RES'  => []
                                              }
           , '.1.3.6.1.4.1.3224.9.1.1.7'   => { 'DESC' => 'Zone Netmask'
                                              , 'OID'  => 'nsIfNetmask'
                                              , 'RES'  => []
                                              }
           );

sub mask2cidr {
    my $mask = shift;
    my $cidr = 0;
    my %conv = ( 255 => 8
               , 254 => 7
               , 252 => 6
               , 248 => 5
               , 240 => 4
               , 224 => 3
               , 192 => 2
               , 128 => 1
               , 0   => 0
               );
    while ($mask =~ /(\d+)/sg) {
        $cidr += $conv{$1};
    }
    return $cidr;
}

my $session = new SNMP::Session( DestHost   => $params{host}
                               , Community  => $params{community}
                               , Version    => $params{version}
                               , UseNumeric => 1
                               );

if ($session->{ErrorNum}) {
    print "Error ".$session->{ErrorNum}." \"".$session->{ErrorStr}."\n en ".$session->{ErrorInd}."\n";
    exit 1;
}

my %arrays=();
my @VarBinds =();
foreach (keys %oids) {
    push @VarBinds, new SNMP::Varbind([$_]);
}
my $VarList = new SNMP::VarList(@VarBinds);
my $ifnum = $session->get('.1.3.6.1.2.1.2.1.0');
my @result = $session->bulkwalk(0, $ifnum, $VarList);

my $i=0;
for my $vbarr (@result) {
    my $oid = $$VarList[$i++]->tag();
    foreach my $v (@$vbarr) {
        push(@{$arrays{$oids{$oid}{OID}}}, $v->val);
    }
}

my %zones;
@zones{@{$arrays{nsZoneCfgId}}} = @{$arrays{nsZoneCfgName}};

if ($config) {
    print "host_name $params{group}\n";
    print "graph_category $params{host}\n";
    print "graph_title Sub-Interface traffic on $params{host}\n";
    print "graph_info  Sub-Interface traffic on $params{host}\n";
    print "graph_args --base 1000\n";
    print "graph_vlabel octets in / out per \${graph_period}\n";
    foreach my $if (@{$arrays{nsIfFlowIfIdx}}) {
        for my $direction ('in', 'out') {
            print "${if}_$params{type}_${direction}.label $arrays{nsIfName}->[$if] $zones{$arrays{nsIfZone}->[$if]} ($arrays{nsIfIp}->[$if]/".&mask2cidr($arrays{nsIfNetmask}->[$if]).") ".uc($direction)."\n";
            print "${if}_$params{type}_${direction}.draw LINE1\n";
            print "${if}_$params{type}_${direction}.type DERIVE\n";
            print "${if}_$params{type}_${direction}.cdef ${if}_$params{type}_${direction},8,*\n";
            print "${if}_$params{type}_${direction}.min 0\n";
            if ($direction eq "in"){
                print "${if}_$params{type}_${direction}.negative ${if}_$params{type}_out\n";
            }
        }
    }
} else {
    foreach my $if (@{$arrays{nsIfFlowIfIdx}}) {
        print "${if}_$params{type}_in.value\t$arrays{nsIfFlowInByte}->[$if]\n";
        print "${if}_$params{type}_out.value\t$arrays{nsIfFlowOutByte}->[$if]\n";
    }
}
