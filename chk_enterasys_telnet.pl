#!/usr/bin/perl
# Generic nagios enterasys check script.

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
                                 , Prompt  => '/.*\(rw\)->/i'
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

    # Remove pagination.
    print STDERR "# Issuing 'set length 0'...";
    $telnet->cmd("set length 0");
    $lastline = $telnet->lastline;
    chomp $lastline;
    if ($telnet->lastline =~ /length/) {
        print STDERR " OK\n";
    } else {
        print STDERR " NOK!\n# Unable to set the teminal length. The last line was: '$lastline'\n";
        push (@criticals, "[$host] Unable to set the teminal length. The last line was: '$lastline'");
        next;
    }

    # Check CPU usage.
    print STDERR "\n# Checking CPU Utilization\n";
    my $result = join('', $telnet->cmd('show system utilization cpu'));
    chomp($result);
    print STDERR $result;
    while ($result =~ /%\s+\d+%\s+(\d+)%/sg) {
        push (@warnings, "[$host] Total CPU Utilizationi (5min): $1%") if $1 > 20;
    }

    # Check Fan Status.
    print STDERR "\n# Checking fan status\n\n";
    $result = join('', $telnet->cmd('show system'));
    $result =~ s/([\s-])+/$1/g;
    while ($result =~ /Switch\s(\d+).+?Fan2-Status\n((?:Ok|Not.+?))\s((?:Ok|Not.+?))\n/sg) {
        print STDERR "Switch $1 -> Fan1:$2 Fan2:$3\n";
        push (@warnings, "[$host] Fan failure on switch $1 -> Fan1:$2 Fan2:$3") if "$2$3" ne "OkOk";
    }

    # Check for stack interconnection problems.
    print STDERR "\n# Checking stack interconnection problems\n\n";
    $result = join('', $telnet->cmd('show switch stack-ports'));
    while ($result =~ /(\d)\s+(?:Up|Down)[\s\d]+\s(\d+)\s+\n\s+(?:Up|Down)[\s\d]+?\s(\d+)\s+\n/sg) {
        print STDERR "Switch $1 has ".($2 + $3)." IC errors\n";
        push (@warnings, "[$host] Switch $1 has ".($2 + $3)." IC errors") if ($2 + $3);
    }

    # Check for detached stack members.
    print STDERR "\n# Checking for detached stack members\n\n";
    my @result = $telnet->cmd('show port status');
    chomp @result;
    my %hash = ();
    map {$hash{$1} = 1 if /^[fg]e\.(\d)\.\d+\s+Detach\s/} @result;
    if (scalar keys %hash) {
        print STDERR "NOK! Found ".(scalar keys %hash)." detached element/s: ".join(', ', sort keys %hash)."\n";
        push (@warnings, "[$host] Found ".(scalar keys %hash)." detached element/s: ".join(', ', sort keys %hash));
    } else {
        print STDERR "OK!\n";
    }

    # Check for spare stack members.
    print STDERR "\n# Checking for spare stack members\n\n";
    # We'll reuse our previous @result array
    %hash = ();
    my ($swnum, $ports) = (0, 0);
    map { ($swnum, $ports) = ($1, $2) if /^[fg]e\.(\d)\.(\d+)/} @result;
    $count = 0;
    foreach (@result) {
        if (/^[fg]e\.(\d)\.\d+\s+[Dd]o\w+\s/) {
            $count++;
            $hash{$1} = 1 if $count == $ports;
        } else {
            $count = 0;
        }
    }
    if (scalar keys %hash or $swnum < 3) {
        print STDERR "OK! Found ".(scalar keys %hash)." spare member/s on the stack (".join(', ', sort keys %hash).") from a total of $swnum elements.\n";
    } else {
        print STDERR "NOK! No spare member/s on a $swnum elements stack\n";
        push (@warnings, "[$host] No spare member/s on a $swnum elements stack");
    }
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
