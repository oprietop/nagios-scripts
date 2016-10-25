#!/usr/bin/perl
# Generic cisco IOS check script.
# Notes:
# Reliability of the interface as a fraction of 255 (255/255 is 100 percent reliability), calculated as an exponential average over 5 minutes.
# txload/rxload=Load on the interface as a fraction of 255 (255/255 is completely saturated), calculated as an exponential average over 5 minutes.

use strict;
use warnings;
use Net::Telnet;

$0 =~ s/.*\///g;
print "Usage: $0 <host/s>\n" and exit 1 unless @ARGV;

my @warnings  = ();
my @criticals = ();
my $user      = 'xxxxx';
my $pass      = 'xxxxx';
my $enable    = 'xxxxx';

foreach my $host (@ARGV) {
    # Establish a telnet connection.
    my $telnet = new Net::Telnet ( Timeout => 5
                                 , Errmode => 'return'
                                 , Prompt  => '/(?m:.*[\w.-]+\s?(?:\(config[^\)]*\))?\s?[\+\$#>]\s?(?:\(enable\))?\s*$)/'
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

    # Enter into EXEC mode.
    print STDERR "# Entering privileged mode...";
    if ($prompt =~ /#$/) {
        print STDERR " Already on EXEC mode!\n";
    } else {
        $telnet->print('enable');
        $telnet->waitfor('/password/i');
        $telnet->cmd($enable);
        $lastline = $telnet->lastline;
        unless ($lastline =~ /denied/i) {
            print STDERR " OK\n";
        } else {
            print STDERR " NOK!\n# Unable to get into EXEC mode. The last line was: '$lastline'\n";
            push (@criticals, "[$host] Unable to get into EXEC mode.  The last line was: '$lastline'");
            next;
        }
    }

    # Remove pagination.
    print STDERR "# Issuing 'terminal length 0'...";
    $telnet->cmd("terminal length 0");
    if ($telnet->lastline =~ /terminal/i) {
        print STDERR " OK\n";
    } else {
        print STDERR " NOK!\n# Unable to set the teminal length.\n";
        push (@criticals, "[$host] Unable to set the teminal length.");
        next;
    }

    # Check environment. Consider output differences with some routers.
    print STDERR "\n# Checking environment\n\n";
    my @output = $telnet->cmd("show env");
    if ($#output == 0) {
        print STDERR "$output[0]";
    } else {
        @output = $telnet->cmd("show env all");
        foreach my $line (@output) {
            if ($line =~ /(^[^\s]+)\sis\s(.+?)$/) {
                my ($component, $status) = ($1, $2);
                print STDERR "[$component] -> [$status]\n";
                push (@warnings, "[$host] Environment: [$component] -> [$status]") if $status =~ /fault/i;
            }
        }
    }

    # Parse the interfaces stats for valuable info.
    print STDERR "\n# Checking duplex, reliability and load\n\n";
    my $output = join('', $telnet->cmd("show interfaces | include is up|reliability|duplex"));
    while ($output =~ /([^\n]+) is up, l[^\n]+\n\s+reliability (\d+)\/255, txload (\d+)\/255, rxload (\d+)\/255\n\s+(\w+)-duplex/sg) {
        my ($interface, $reliability, $txload, $rxload, $duplex) = ($1, int(($2*100)/255), int(($3*100)/255), int(($4*100)/255), $5);
        printf STDERR ("%-24s Duplex: %s Reliability: %2d%% TXload: %2d%% RXload: %2d%%\n", $interface, $duplex, $reliability, $txload, $rxload);
        push (@warnings, "[$host] $interface is working on Half-Duplex") if $duplex =~ /half/i;
        push (@warnings, "[$host] $interface is under 100% reliablity ($reliability%)") if $reliability < 100;
        push (@warnings, "[$host] $interface TX load is $txload%") if $txload > 70;
        push (@warnings, "[$host] $interface RX load is $rxload%") if $rxload > 70;
    }

    # Display the BGP peers current status if any.
    print STDERR "\n# Checking BGP connections\n\n";
    $output = join('', $telnet->cmd("show bgp neighbors | include BGP neighbor is|Description:|BGP state ="));
    my $counter = 0;
    while ($output =~ /BGP neighbor is ([^,]+),[^\n]+\n\s+Description: ([^\n]+)[\n\s]+BGP state = ([^,]+), up for ([^\n]+)\n/sg) {
        $counter++;
        my ($rpeer, $rpeer_desc, $state, $time) = ($1, uc($2), uc($3), $4);
        print STDERR "Remote BGP peer $rpeer($rpeer_desc) is on $state state for $time\n";
        push (@warnings, "[$host] Remote BGP peer $rpeer($rpeer_desc) is on $state state for $time") unless $state =~ /ESTABLISHED/i;
    }
    print STDERR "No BGP peers found.\n" unless $counter;
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
