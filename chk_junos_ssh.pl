#!/usr/bin/perl

use warnings;
use strict;
use Net::OpenSSH;
# $Net::OpenSSH::debug |= 16;

$0 =~ s/.*\///g;
print "Usage: $0 <host/s>\n" and exit 1 unless @ARGV;

my $user      = 'xxxxx';
my $pass      = 'xxxxx';
my @warnings  = ();
my @criticals = ();

foreach my $host (@ARGV) {
    # Connect via ssh
    print STDERR "\n# Connecting to '$host' via ssh... ";
    my $ssh = Net::OpenSSH->new( "${user}:${pass}\@${host}"
                               , master_opts => [-o => "StrictHostKeyChecking=no"]
                               , timeout     => 5
                               );
    if ($ssh->error) {
        push (@criticals, "[$host] Can't connect to '$host'.");
        next;
    } else {
        print STDERR "OK\n";
    }
    # Check hardware alarms
    print STDERR "\n# Checking chassis alarms\n\n";
    my $alarms = $ssh->capture2('show chassis alarms');
    chomp($alarms);
    print STDERR "$alarms\n";
    push (@warnings, "[$host] -$alarms-") if $alarms !~ /^No/;

    # Check hardware presence, fans and temperatures
    print STDERR "\n# Checking chassis enviroment\n\n";
    my $environment = $ssh->capture2('show chassis environment');
    while ($environment =~ /(FPC\s\d\s.+?)\s+\s(\w+)/sg) {
        my ($item, $status) = ($1, $2);
        print STDERR "$item ($status)\n";
        push (@warnings, "[$host] $item ($status)") if $status !~ /^(?:OK|Absent)$/;
    }

    # Check Routing Engine Status
    print STDERR "\n# Checking chassis routing-engine\n\n";
    my $rengine = $ssh->capture2('show chassis routing-engine');
    while ($rengine =~ /Slot\s(\d)\W+Current\sstate\s+(\w+)\W+Election\spriority\s+(\w+)\s.+?Memory\sutilization\s+(\d+)\spercent.+?Idle\s+(\d+)\spercent.+?Serial\sID\s+(\w+).+?[\d\.]+\s+([\d\.]+)\s+[\d\.]+/sg) {
        my ($slot, $state, $prio, $memory, $idlecpu, $serial, $load) = ($1, $2, $3, $4, $5, $6, $7);
        print STDERR "Slot $slot S/N: $serial HA_State: $state($prio) Mem: $memory% I_CPU: $idlecpu% 5M_Load: $load\n";
        push (@warnings, "[$host] Slot $slot S/N: $serial HA_State: $state($prio)") if $state ne $prio;
        push (@warnings, "[$host] Slot $slot S/N: $serial Mem: $memory%")           if $memory > 80;
        push (@warnings, "[$host] Slot $slot S/N: $serial I_CPU: $idlecpu%")        if $idlecpu < 5;
        push (@warnings, "[$host] Slot $slot S/N: $serial 5M_Load: $load")          if substr($load, 0, 4) > 2;
    }
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
