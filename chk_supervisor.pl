#!/usr/bin/perl
# Query the supervisor daemon via api.

use warnings;
use strict;
use RPC::XML::Client;
use Data::Dumper;

my @hosts = qw/host1 host2/;
my @warnings  = ();
my @criticals = ();

foreach my $host (sort @hosts) {
    my $xen = RPC::XML::Client->new("http://$host:9001/RPC2");
    print STDERR "$host:\n";
    my $proc_array = $xen->simple_request("supervisor.getAllProcessInfo");
    push (@criticals, "[$host] Problems gettting processess...\n") unless $proc_array;
    foreach my $proc_hash ( @{ $proc_array } ) {
        if ($proc_hash->{statename} and $proc_hash->{statename} eq 'RUNNING') {
            print STDERR "\t$proc_hash->{name} -> $proc_hash->{statename}\n";
        } else {
            push (@criticals, "[$host] $proc_hash->{name} status is $proc_hash->{statename}\n");
        }
    }
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
