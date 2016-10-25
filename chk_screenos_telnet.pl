#!/usr/bin/perl
# Generic nagios screenos check script.

use strict;
use warnings;
use Net::Telnet;
use Data::Dumper;

$0 =~ s/.*\///g;
print "Usage: $0 <host/s>\n" and exit 1 unless @ARGV;

my @warnings  = ();
my @criticals = ();
my $user      = 'xxxxx';
my $pass      = 'xxxxx';

foreach my $host (@ARGV) {
    # Establish a telnet connection.
    my $telnet = new Net::Telnet ( Timeout => 1
                                 , Errmode => 'return'
                                 , Prompt  => '/.*\(\w\)->/i'
                                 );
    my $count = 0;
    my $attempts = 3;
    print STDERR "# Connecting to '$host' via telnet.";
    while ($count != $attempts) {
        $count++;
        print STDERR " $count/$attempts...";
        print STDERR " OK\n" and last if $telnet->open($host);
    }
    if ($count == $attempts) {
        print STDERR " NOK!\n# Can't connect to '$host' after $count attempts.\n";
        push (@criticals, "[$host] Can't connect to '$host' after $count attempts.");
        next;
    }

    # Authenticate with our user/pass pair.
    print STDERR "# Authenticating with user/pass...";
    $telnet->login($user, $pass);
    my $prompt = $telnet->last_prompt;
    $prompt =~ tr/\015//d;
    my $lastline = $telnet->lastline;
    chomp $lastline;
    if ($prompt) {
        print STDERR " OK\n";
    } else {
        print STDERR " NOK! Unable to get prompt. The last line was: '$lastline'\n";
        push (@criticals, "[$host] Unable to get prompt. The last line was: '$lastline'");
        next;
    }

    print STDERR "\n# Checking NSRP status\n\n";
    my %states = ( M => 'Master'
                 , B => 'Backup'
                 , I => 'Inoperable'
                 );
    my ($result) = $prompt =~ /\w\((\w)\)->/;
    if ($result eq "I") {
        print STDERR "The firewall is in '$states{$result}' NSRP state.\n";
        push (@warnings, "[$host] The firewall is in '$states{$result}' NSRP state");
    } else {
        print STDERR "The firewall is in '$states{$result}' NSRP state.\n";
    }

    print STDERR "\n# Checking Session usage\n\n";
    $result = join('', $telnet->cmd('get session info'));
    if (my ($alloc, $max) = $result =~ /alloc (\d+)\/max (\d+),/) {
        my $percent =  sprintf ("%.2f", ($alloc*100)/$max);
        print STDERR "$alloc of $max sessions allocated, ($percent%)\n";
        push (@warnings, "[$host] Session usage is $percent%") if $percent > 50;
    }

    print STDERR "\n# Checking Memory usage\n\n";
    $result = join('', $telnet->cmd('get memory'));
    print STDERR $result;
    if (my ($malloc, $mleft) = $result =~ /allocated (\d+), left (\d+),/) {
        push (@warnings, "[$host] High memory usage") if $malloc > (2*$mleft);
    }

    print STDERR "\n# Checking CPU performance\n\n";
    $result = join('', $telnet->cmd('get perf cpu'));
    print STDERR $result;
    if (my ($cpu) = $result =~ /Last 5 minutes:  (\d+)%/) {
        push (@warnings, "[$host] Cpu utilization is at $cpu%") if $cpu > 50;
    }
}

# Print every abnormal output and exit appropiately.
print join("\n ", @criticals);
print join("\n ", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
