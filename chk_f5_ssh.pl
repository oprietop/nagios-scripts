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
my %known_ips = ( 'xxx.xxx.xxx.xxx' => 'someone'
                );

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

    # Check if we are under our desired HA status
    print STDERR "\n# Checking HA status\n\n";
    my $ha_current = lc($ssh->capture2('cat /var/prompt/ps1'));
    chomp($ha_current);
    my $failover = $ssh->capture2("bigpipe failover force $ha_current show");
    if (my ($status) = $failover =~ /: (\w+)/) {
        if ($status eq "enable") {
            print STDERR "Host is in '$ha_current' status as intended.\n";
        } else {
            print STDERR "Host is in '$ha_current', but it shouldn't!.\n";
            push (@warnings, "[$host] Not in intended failover state");
        }
    }

    # Check if the config is synced with our pair
    print STDERR "\n# Checking Config Sync\n\n";
    my @state = $ssh->capture('bigpipe config sync show');
    my $confsync = $state[1];
    chomp($confsync);
    $confsync =~ s/^\s+//g;
    print STDERR "$confsync\n";
    my @logs = $ssh->capture('zegrep -v "192.168.233.69|10.10.5." /var/log/audit.1.gz /var/log/audit');
    my $count = 0;
    foreach my $line (reverse @logs) {
        if ($line =~ /user=([^ ]+) partition=[^ ]+ level=[^ ]+ tty=\d+ host=([^ ]+) attempts=\d+ start="([^"]+)"/sg) {
            my $name = " (???)";
            $name = " ($known_ips{$2})" if $known_ips{$2};
            print STDERR "[$3] $1 logged from ${2}${name}\n";
            last if ++$count == 8;
        }
    }
    if ($confsync !~ "Status (?:0|disabled)") {
        push (@warnings, "[$host] Config sync status: $confsync");
    }

    # Check media for Half-Duplex interfaces.
    print STDERR "\n# Checking duplex status\n\n";
    my $media = $ssh->capture2('bigpipe interface all media');
    while ($media =~ /INTERFACE (\S+)\s-\s[^\)]+?\s\((\w+)\s(\w+)\)/sg) {
        my ($iname, $ispeed, $iduplex) = ($1, $2, $3);
        print STDERR "Interface $iname\tSpeed: $ispeed Duplex: $iduplex\n";
        push (@warnings, "[$host] Interface $iname is working on Half-Duplex") if $iduplex =~ /half/;
    }

    # Check the memory usage of the TMM
    print STDERR "\n# Checking the TMM memory usage\n\n";
    my %units = ( 'M' => 1000
                , 'G' => 1000000
                , 'T' => 1000000000
                );
    my $result = $ssh->capture2('bigpipe global');
    if (my ($total, $total_u, $used, $used_u) = $result =~ /memory[^=]+= \(([\.\d]+)(\w), ([\.\d]+)(\w)\)/) {
        my $percent =  sprintf ("%.2f", (($used*$units{$used_u})*100)/($total*$units{$total_u}));
        print STDERR "TMM is using ${used}${used_u} of ${total}${total_u} ($percent%) of memory.\n";
        push (@warnings, "[$host] High memory usage ($percent%)") if $percent > 90;
    }
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
