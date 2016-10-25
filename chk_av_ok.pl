#!/usr/bin/perl
# Parse an epo Antivirus file and report outdated agents

use warnings;
use strict;

my $file = '/mnt/epo/registreDAT.csv';
my @warnings = ();

open(FH, '<', $file);
chomp(my @lines = <FH>);
close FH;
shift(@lines); # Remove the first line

my $hashref;
my $max_version = 0;
foreach my $line (@lines) {
    my @array = split(',', $line);
    $max_version = $array[-2] if $array[-2] > $max_version;
    $hashref->{$array[0]} = $array[-2];
    print STDERR "$array[0] = $array[-2]\n";
}
print STDERR "\nMax Version is: $max_version\n";

map { push (@warnings, $_) if $hashref->{$_} < $max_version } keys %{ $hashref };
print scalar @warnings.' outdated agents: [ '.join(', ', @warnings).' ]' and exit 1 if @warnings;
print 'OK' and exit 0;
