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
                               , timeout => 5
                               );
    if ($ssh->error) {
        push (@criticals, "[$host] Can't connect to '$host'.");
        next;
    } else {
        print STDERR "OK\n";
    }

    # Check hardware alarms
    print STDERR "\n# Checking system alarms for Fans, PSUs and voltages\n";
    my @sysctl = $ssh->capture('ipsctl -a');
    foreach my $line (@sysctl) {
        print STDERR "$line" if $line =~ /^hw:sys_stat.+?:(?:fault|location)\s=/;
        push (@warnings, "[$host] $1 $2 is faulty") if $line =~ /^hw:sys_stat:(\w+):(\d+):fault\s=\s[^0]/;
    }

    # Check cpu usage
    print STDERR "\n# Checking cpu usage\n\n";
    my $vmstat = $ssh->capture2("vmstat 1 3");
    $vmstat =~ s/^\n//g;
    print STDERR "$vmstat";
    if (my ($idle) = $vmstat =~ /(\d+)\W+$/s) {
        my $cpu = (100-$idle);
        push (@warnings, "[$host] CPU usage is $cpu%") if $cpu > 80;
    }

    # Check memory and Disk
    print STDERR "\n# Checking memory and disk usage\n";
    my $useful = $ssh->capture2("clish -c 'show useful-stats'");
    $useful =~ s/[\W]+$//;
    print STDERR "$useful\n";
    if ($useful =~ /Real\sMemory\sUsed\s+(\d+)%\W+Disk\sCapacity\s+(\d+)%/s) {
        my ($memory, $disk) = ($1, $2);
        push (@warnings, "[$host] Memory usage is $memory%") if $memory > 80;
        push (@warnings, "[$host] Disk usage is $disk%") if $disk > 80;
    }

    # Check VRRP redundancy
    print STDERR "\n# Checking VRRP status\n";
    my $vrrp = $ssh->capture2("clish -c 'show vrrp'");
    $vrrp =~ s/[\W]+$//;;
    print STDERR "$vrrp\n";
    if ($vrrp =~ /state\s(\d+)\W+In\sBackup\sstate\s(\d+)\W+In\sMaster\sstate\s(\d+)/s) {
        my ($init, $backup, $master) = ($1, $2, $3);
        push (@warnings, "[$host] Virtual router states. Init: $init Backup: $backup Master: $master") unless ($backup == 0 and $master == 5) or ($backup == 5 and $master == 0);
    }
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
