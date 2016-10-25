#!/usr/bin/perl
# Nagios script to check Palo Alto (PAN) devices via API.

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use IO::Handle;
use XML::Simple;

my $host = '192.168.168.192';
my $key  = 'XXXXXXXXXXXXXXX';
my @warnings  = ();
my @criticals = ();

my $ua = LWP::UserAgent->new( agent         => 'Mac Safari'             # I'm a cool web browser
                            , timeout       => 5                        # Idle timeout (Seconds)
                            , show_progress => 0                        # Fancy progressbar
                            , ssl_opts      => { verify_hostname => 0 } # Trust everything                          );
                            );

sub api_post {
    my $args     = shift || '';
    $ua->timeout(5);
    my $response = $ua->request( POST "https://$host/api/?$args"
                               , [ 'key' => $key ]
                               );
    my $xmlref;
    $response->is_success ? $xmlref = XMLin($response->decoded_content) : return $response->status_line;
    $xmlref->{code} ? return $xmlref->{result}->{msg} : return $xmlref->{result};
}

# System info
print STDERR "# Sysinfo\n";
my $top = api_post("type=op&cmd=<show><system><resources><follow></follow></resources></system></show>");
if ($top =~ /load average: ([\d\.]+)/) {
    my $load = $1;
    print STDERR "$load\t1M Load\n";
    push (@warnings, "[$host] 1M Load is $load") if $load > 20;
}

if ($top =~ /([\d\.]+)%id/) {
    my $idle_cpu = int($1);
    print STDERR "$idle_cpu%\tIdle CPU\n";
    push (@warnings, "[$host] Idle CPUis $idle_cpu%") if $idle_cpu < 3;
}

if ($top =~ /(\d+) total/) {
    my $procs = $1;
    print STDERR "$procs\tTotal Processes\n";
    push (@warnings, "[$host] Got $procs zombie processes") if $procs > 500;
}

if ($top =~ /(\d+) zombie/) {
    my $zombies = $1;
    print STDERR "$zombies\tZombie Processes\n";
    push (@warnings, "[$host] Got $zombies zombie processes") if $zombies;
}

if ($top =~ /Mem:\s+(\w+) total,\s+(\w+) used,\s+(\w+) free,\s+(\w+) buffers/) {
    my @mem = ($1, $2, $3, $4);
    s/k/000/g for @mem;
    my ($total, $used, $free, $buffers) = @mem;
    my $free_percent = int(($free*100)/$total);
    print "$free_percent%\tFree Mem\n";
    push (@warnings, "[$host] Free Memory is $free_percent%") if $free_percent < 3;
}

if ($top =~ /Swap:\s+(\w+) total,\s+(\w+) used,\s+(\w+) free,\s+(\w+) cached/) {
    my @mem = ($1, $2, $3, $4);
    s/k/000/g for @mem;
    my ($total, $used, $free, $cached) = @mem;
    my $free_percent = int(($free*100)/$total);
    print STDERR "$free_percent%\tFree Swap\n\n";
    push (@warnings, "[$host] Free Swap is $free_percent%") if $free_percent < 95;
}

# Session info
print STDERR "# Session Info\n";
my $sess_ref = api_post("type=op&cmd=<show><session><info></info></session></show>");
if ($sess_ref->{'num-max'}) {
    my $sess_usage = int(($sess_ref->{'num-active'}*100)/$sess_ref->{'num-max'});
    print STDERR "$sess_usage% Session Usage\n\n";
    push (@warnings, "[$host] Session usage is $sess_usage%") if $sess_usage > 50;
}

# Disk Space
print STDERR "# Disk Usage\n";
my $df = api_post("type=op&cmd=<show><system><disk-space></disk-space></system></show>");
while ($df =~ /(\d+)% ([\/\w]+)/sg) {
    my ($percent, $part) = ($1, $2);
    print STDERR "$percent%\t$part\n";
    push (@warnings,  "[$host] Partition $part usage is $percent%") if $percent > 90;
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
