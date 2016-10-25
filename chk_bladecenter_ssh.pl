#!/usr/bin/perl

use warnings;
use strict;
use Net::OpenSSH;
#$Net::OpenSSH::debug |= 16;

$0 =~ s/.*\///g;
print "Usage: $0 <host/s>\n" and exit 1 unless @ARGV;

my $user      = 'XXXX';
my $pass      = 'XXXX';
my @warnings  = ();
my @criticals = ();

foreach my $host (@ARGV) {
    # Connect via ssh
    print STDERR "\n# Connecting to '$host' via ssh... ";
    my $ssh = Net::OpenSSH->new( "${user}:${pass}\@${host}"
                               , master_opts => [-o => "StrictHostKeyChecking=no"]
                               , timeout     => 5
                               , master_stderr_discard => 1
                               );
    if ($ssh->error) {
        push (@criticals, "[$host] Can't connect to '$host'.");
        next;
    } else {
        print STDERR "OK\n";
    }

    # Check the enclosure health status.
    print STDERR "\n# Checking health status\n";
    my @result = $ssh->capture('health -l all');
    foreach my $line (@result) {
    $line =~ s/\s//g;
        if ($line =~ /([^:]+):([^:]+)/) {
            my ($key, $value) = ($1, $2);
            print STDERR "$key ($value)\n";
            push (@warnings, "[$host] $key status $value") unless $value =~ /OK|Non/;
        }
    }
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;

