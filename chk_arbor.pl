#!/usr/bin/perl

use strict;
use warnings;
use SNMP;

my @warnings  = ();
my @criticals = ();

my $session = new SNMP::Session( DestHost    => 'arbor.hostname'
                               , Community   => 'public'
                               , Version     => 2
                               );

print STDERR "# State of faults within a Pravail device\n";
my $result = $session->get('.1.3.6.1.4.1.9694.1.6.2.1.0');
$result =~ s/(Interface Link \'(?:ext|int)[2-9]\' is \'Down\')//g; # We will ignore the down state for the unuses interfaces
$result =~ s/^\s+|\s+$//g;
$result = 'none' unless $result;
print STDERR "pravailHostFault: $result\n";
push (@criticals, "Fallos: $result") if $result ne 'none':

print STDERR "# Average number of processes in run queue during last 1 min.\n";
$result = $session->get('.1.3.6.1.4.1.9694.1.6.2.3.0');
$result = ($result / 100);
print STDERR "deviceCpuLoadAvg1min: $result\n";
push (@criticals, "deviceCpuLoadAvg1min: $result") if $result > 5;
push (@warnings, "deviceCpuLoadAvg1min: $result") if $result > 20;

print STDERR "# Percentage of primary data partition used.\n";
$result = $session->get('.1.3.6.1.4.1.9694.1.6.2.6.0');
print STDERR "deviceDiskUsage: $result%\n";
push (@criticals, "deviceDiskUsage: $result%") if $result > 90;
push (@warnings, "deviceDiskUsage: $result%") if $result > 50;

print STDERR "# Percentage of physical memory used.\n";
$result = $session->get('.1.3.6.1.4.1.9694.1.6.2.7.0');
print STDERR "devicePhysicalMemoryUsage: $result%\n";
push (@criticals, "devicePhysicalMemoryUsage: $result%") if $result > 90;
push (@warnings, "devicePhysicalMemoryUsage: $result%") if $result > 50;

print STDERR "# Percentage of swap space used.\n";
$result = $session->get('.1.3.6.1.4.1.9694.1.6.2.8.0');
print STDERR "deviceSwapSpaceUsage: $result%\n";
push (@criticals, "deviceSwapSpaceUsage: $result%") if $result > 20;
push (@warnings, "deviceSwapSpaceUsage: $result%") if $result > 0;

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
