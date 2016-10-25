#!/usr/bin/perl -w
use strict;
use Net::Telnet;
use Getopt::Long;

$0 =~ s/.*\///g;
my $ips = undef;
GetOptions ('ips=s' => \$ips);

unless (@ARGV and $ips) {
    print <<EOF;
Usage: $0 <switch> --ips <hosts>
args:
\t<switch>\tDevice to interrogate, any extra host specified as an argument will also be queried.
\t--ips, -i\tA single or a comma-separated list of <hosts> to ping.
Example:
\t$0 jun1 jun2 -i 192.168.233.1,192.168.233.2,192.168.233.4,192.168.233.6
EOF
exit 1;
}

sub check_ip_host(@) {
    my $validip = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\$";
    my $validhost = "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])\$";
    @_ ? my @badhosts = grep { $_ !~ /(?:$validip|$validhost)/ } @_ : print "Empty array!\n";
    exit 1 unless @_;
    @badhosts ? print join(", ", @badhosts)." IP o Hostname inválido/s.\n" : return 0;
    exit 1 if @badhosts;
}

&check_ip_host(@ARGV);
my @iplist = split (",", $ips);
&check_ip_host(@iplist);

my $errcount = 0;
foreach my $switch (@ARGV) {
    my $telnet = new Net::Telnet ( Timeout  => 6
                             , Errmode  => 'return'
                             , Prompt   => '/rw@.*>/i'
                             );
    my $count = 0;
    while ($count++ < 5) {
        last if $telnet->open($switch);
    }
    $telnet->login('XXXX', 'XXXXXXXXXXXX');
    $telnet->cmd('set cli screen-length 0');
    foreach (@iplist) {
        my $ping = join('', $telnet->cmd("ping routing-instance datos count 1 wait 2 $_"));
        while ($ping =~ /(\d+)% packet loss/sg) {
            $1 ? print "$switch -> $_ (NOK)\n" : print "$switch -> $_ (OK!)\n";
            $errcount++ if $1;
        }
    }
    $telnet->close;
}
$errcount ? exit 1 : exit 0
