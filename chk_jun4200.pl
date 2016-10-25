#!/usr/bin/perl -w
# http://search.cpan.org/src/HARDAKER/SNMP-5.0401/t/bulkwalk.t
# Munin traffic/error/discards snmp poller for juniper EX hardware.
# Filename example: snmp_asd_device_subifs

use strict;
use SNMP;

my $config = 1 if $ARGV[0] and lc($ARGV[0]) eq "config";

my %params = ( community => $ENV{community} || 'default@public' );

if ($0 =~ /snmp_([^_]+)_([^_]+)(?:$|_(octets|errors|discards)$)/) {
    $params{group} = $1;
    $params{host}  = $2;
    $params{type}  = $3 || 'octets';
} else {
    die "regex phail!\n"
}

my %type2oid = ( octets    => { IN  => 'ifHCInOctets'
                              , OUT => 'ifHCOutOctets'
                              }
               , errors    => { IN  => 'ifInErrors'
                              , OUT => 'ifOutErrors'
                              }
               , discards  => { IN  => 'ifInDiscards'
                              , OUT => 'ifOutDiscards'
                              }
               );

my %oids = ( '.1.3.6.1.2.1.1.1'         => 'sysDescr'
           , '.1.3.6.1.2.1.2.2.1.1'     => 'ifIndex'
           , '.1.3.6.1.2.1.2.2.1.2'     => 'ifDescr'
           , '.1.3.6.1.2.1.2.2.1.3'     => 'ifType'
           , '.1.3.6.1.2.1.2.2.1.8'     => 'ifOperStatus'
           , '.1.3.6.1.2.1.31.1.1.1.18' => 'ifAlias'
           , '.1.3.6.1.2.1.31.1.1.1.6'  => 'ifHCInOctets'
           , '.1.3.6.1.2.1.31.1.1.1.10' => 'ifHCOutOctets'
           , '.1.3.6.1.2.1.2.2.1.14'    => 'ifInErrors'
           , '.1.3.6.1.2.1.2.2.1.20'    => 'ifOutErrors'
           , '.1.3.6.1.2.1.2.2.1.13'    => 'ifInDiscards'
           , '.1.3.6.1.2.1.2.2.1.19'    => 'ifOutDiscards'
           );

my $session = new SNMP::Session( DestHost   => $params{host}
                               , Community  => $params{community}
                               , Version    => 2 # v2 is required for Bulkwalk.
                               , Timeout    => 5000000
                               );
die "Error ".$session->{ErrorNum}." \"".$session->{ErrorStr}."\" en ".$session->{ErrorInd}."\n" if $session->{ErrorNum};

my %arrays=();
my @VarBinds =();
my @type_keys = grep { $_ ne $params{type} } keys %type2oid; # Array containing oids we don't need to poll.
foreach my $oid (keys %oids) {
    next if scalar grep { lc($oids{$oid}) =~ $_ } @type_keys; # Skip oids from the @type_keys array.
    push @VarBinds, new SNMP::Varbind([$oid]);
}
my $VarList = new SNMP::VarList(@VarBinds);
my $ifnum = $session->get('.1.3.6.1.2.1.2.1.0');
die "Error ".$session->{ErrorNum}." \"".$session->{ErrorStr}."\" en ".$session->{ErrorInd}."\n" if $session->{ErrorNum};

# We'll retrieve everything with a single query via SNMPv2 bulkwalk.
my @result = $session->bulkwalk(0, $ifnum, $VarList);
die "Error ".$session->{ErrorNum}." \"".$session->{ErrorStr}."\" en ".$session->{ErrorInd}."\n" if $session->{ErrorNum};

my $i = 0;
for my $vbarr (@result) {
    my $oid = $$VarList[$i++]->tag();
    foreach my $v (@$vbarr) {
        push(@{$arrays{$oids{$oid}}}, $v->val);
    }
}

# Trim a bit the system description.
$arrays{sysDescr}->[0] =~ s/\s#.*//g;

my $ifs = scalar @{$arrays{ifIndex}} or die "No interfaces retrieved.\n";

if ($config) {
    print "host_name $params{group}\n";
    print "graph_category $params{host}\n";
    print "graph_title ".ucfirst($params{type})." on $params{host}\n";
    print "graph_info $arrays{sysDescr}->[0]\n";
    print "graph_args --base 1000\n";
    print "graph_vlabel ".ucfirst($params{type})." in/out per \${graph_period}\n";
    foreach my $if (0..$ifs-1) {
        # http://www.iana.org/assignments/ianaiftype-mib we'll use ethernetCsmacd(6)
        next unless $arrays{ifIndex}->[$if] and $arrays{ifDescr}->[$if] and $arrays{ifType}->[$if] and $arrays{ifType}->[$if] == 6;
        # http://tools.cisco.com/Support/SNMP/do/BrowseOID.do?translate=Translate&objectInput=1.3.6.1.2.1.2.2.1.8
        next if $arrays{ifOperStatus}->[$if] gt 1;
        for my $direction ('in', 'out') {
            my $current = "$arrays{ifIndex}->[$if]_$params{type}_${direction}";
            print "$current.label $arrays{ifDescr}->[$if] ($arrays{ifAlias}->[$if]) ".uc(${direction})."\n";
            print "$current.negative $arrays{ifIndex}->[$if]_$params{type}_out\n" if $direction eq "in";
            print "$current.draw LINE1\n";
            print "$current.type DERIVE\n";
            print "$current.cdef $arrays{ifIndex}->[$if]_$params{type}_${direction},8,*\n";
            print "$current.max 2000000000\n";
            print "$current.min 0\n";
        }
    }
} else {
    foreach my $if (0..$ifs-1) {
        next unless $arrays{ifIndex}->[$if] and $arrays{ifDescr}->[$if] and $arrays{ifType}->[$if] and $arrays{ifType}->[$if] == 6;
        next if $arrays{ifOperStatus}->[$if] gt 1;
        print "$arrays{ifIndex}->[$if]_$params{type}_in.value\t$arrays{$type2oid{$params{type}}{IN}}->[$if]\n";
        print "$arrays{ifIndex}->[$if]_$params{type}_out.value\t$arrays{$type2oid{$params{type}}{OUT}}->[$if]\n";
    }
}
