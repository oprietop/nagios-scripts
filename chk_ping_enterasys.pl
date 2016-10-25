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
\t$0 ent1 ent2 -i 192.168.238.1,192.168.238.2,192.168.238.3
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
    my $telnet = new Net::Telnet ( Timeout => 6
                                 , Errmode => 'return'
                                 , Prompt  => '/(?m:.*[\w.-]+\s?(?:\(config[^\)]*\))?\s?[\+\$#>]\s?(?:\(enable\))?\s*$)/'
                                 );
    my $count = 0;
    while ($count++ < 5) {
        last if $telnet->open($switch);
    }
    $telnet->login('USER', 'PASSWORD');
    $telnet->cmd('router');
    foreach (@iplist) {
        my $ping = join('', $telnet->cmd("ping $_"));
        print "$ping\n";
        $ping =~ /, 0% packet loss/ ? print "$switch -> $_ (OK)\n" : print "$switch -> $_ (NOK!)\n";
        $errcount++ if $ping =~ /, 100% packet loss/;
    }
    $telnet->close;
}
$errcount ? exit 1 : exit 0
