#!/usr/bin/perl -w
# Count the total AP number and report Missing/New ones on cisco wlc controllers
# Note: when there's a legit AP change just delete the ".aps" file

use strict;
use warnings;
use SNMP;
use Storable;
use Cwd 'abs_path';

# Editable Vars
my $host      = '192.168.1.61'; # Better use the virtual IP od the wlc cluster.
my $community = 'public';
# Fixed Vars
my $oid       ='1.3.6.1.4.1.14179.2.2.1.1.3'; # ApName
my $fullpath  = abs_path($0);
my $VarList   = new SNMP::VarList( new SNMP::Varbind([$oid]) );
my $session   = new SNMP::Session( 'DestHost'  => $host
                                 , 'Community' => $community
                                 , 'Version'   => '2c'    # No bulkwalk on v1
                                 );

# Fetch the ApName table into an array.
my ($result) = $session->bulkwalk(0, $session->get('.1.3.6.1.2.1.2.1.0'), $VarList);
my @aps = sort map { $_->[2] } @{ $result };
my $apnum = scalar @aps;
$apnum or die "WLC($host) Got 0 APs!\n";

# Serialize our array if not already stored.
if (@aps and not -f "$fullpath.aps") {
    store(\@aps, "$fullpath.aps");
    print STDERR "Creating $fullpath.aps file!\n";
}

# Retrieve our saved array to compare to.
my @restored_aps = @{ retrieve("$fullpath.aps") } if -f "$fullpath.aps";
my $stored_apnum = scalar @restored_aps;

# Print differences if any and exit appropiately.
my %count = ();
my @diff = ();
$count{$_}++ foreach (@aps, @restored_aps);
foreach my $ap (keys %count) {
    push(@diff, $ap) unless $count{$ap} == 2;
}
print 'Missing/New APs: [ '.join(', ', @diff)." ]\n" if @diff;
exit 1 if @diff;
print "WLC($host) Has $apnum aps.";
exit 0;
