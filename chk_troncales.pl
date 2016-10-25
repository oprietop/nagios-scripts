#!/usr/bin/perl -w
use strict;
use Net::Telnet;
use GraphViz;
use Data::Dumper;

my %chuis=( '.1.3.6.1.4.1.5624.2.2.220'    => { name   => 'C2H124-48'
                                              , user   => 'xxxxxxx'
                                              , pass   => 'xxxxxxx'
                                              , chkcmd => 'ping'
                                              , regexp => 'is alive'
                                              }
          , '.1.3.6.1.4.1.2636.1.1.1.2.31' => { name   => 'ex4200-24p'
                                              , user   => 'xxxxxxx'
                                              , pass   => 'xxxxxxx'
                                              , runcmd => 'set cli screen-length 0'
                                              , chkcmd => 'ping count 1 wait 1 ttl 1'
                                              , regexp => ', 0% packet loss'
                                              }
          );

my %trons=( 'host1' => { IP => '192.168.0.1'
                       , ID => '.1.3.6.1.4.1.5624.2.2.220'
                       }
          , 'host2' => { IP => '192.168.0.2'
                       , ID => '.1.3.6.1.4.1.5624.2.2.220'
                       }
          , 'host3' => { IP => '192.168.0.3'
                       , ID => '.1.3.6.1.4.1.2636.1.1.1.2.31'
                       }
          );

my %vpns=( 666 => { NAME  => 'VLAN 666'
                  , NODES => { 'host1' => '192.168.2.1'
                             , 'host2' => '192.168.2.2'
                             , 'host3' => '192.168.2.3'
                             }
                  }
         , 667 => { NAME  => 'VLAN 667'
                  , NODES => { 'host1' => '192.168.3.7'
                             , 'host2' => '192.168.3.8'
                             }
                  }
         );

my @colors=sort { rand(3) - 1 } qw/669999 668099 666699 806699 996699 996680 996666 998066 999966 809966 669966 669980 8BB1B1 AFCACA B18B8B CAAFAF 999966 AD9174 7C6E45/;

map {$vpns{$_}{COLOR} = "#".pop(@colors)} keys %vpns;

my $g = GraphViz->new( name     => 'Troncales'
                     , layout   => 'dot'
                     , rankdir  => 'TB'
                     , node     => { shape     => 'box'
                                   , style     => 'filled'
                                   , fillcolor => 'lightgray'
                                   , fontname  => 'terminus'
                                   , fontsize  => 7
                                   }
                     , edge     => { color     => 'blue'
                                   , fontname  => 'terminus'
                                   }
                     );

my %added=();
foreach my $tron (sort {rand() <=> 0.5} keys %trons) {
    print "# $tron ($trons{$tron}{IP})\n" unless $ARGV[0];
    my $sysObjectID = 0;

    if (defined $trons{$tron}{ID}) {
        $sysObjectID = $trons{$tron}{ID};
    } else {
        print "#\tEl troncal $tron no tiene ID\n" unless $ARGV[0];
    }

    my $telnet = new Net::Telnet ( Timeout => 10
                                 , Errmode => 'return'
                                 , Prompt  => '/(?m:.*[\w.-]+\s?(?:\(config[^\)]*\))?\s?[\+\$#>]\s?(?:\(enable\))?\s*$)/'
                                 );

    $telnet->open($trons{$tron}{IP});
    if ($telnet->errmsg) {
        print "#\t$telnet->errms\n" unless $ARGV[0];
    }

    $telnet->login($chuis{$sysObjectID}{user}, $chuis{$sysObjectID}{pass});
    unless ($telnet->last_prompt) {
        print "#\tUnable to get prompt.\n" unless $ARGV[0];
    }

    $telnet->cmd($chuis{$sysObjectID}{runcmd}) if ($chuis{$sysObjectID}{runcmd});
    foreach my $vpn (keys %vpns) {
        if ($vpns{$vpn}{NODES}{$tron}) {
            foreach my $node (keys %{$vpns{$vpn}{NODES}}) {
                if ($node ne $tron) {
                    my ($srcip, $dstip)     = ($vpns{$vpn}{NODES}{$tron}, $vpns{$vpn}{NODES}{$node});
                    my ($clustyle, $clusfc) = ('filled', 'white');
                    ($clustyle, $clusfc) = ('filled', 'red') if $telnet->errmsg;

                    my $shape = 'box';
                    $shape = 'house' if ($vpns{$vpn}{NAME} =~ /acrolan/);

                    $g->add_node( $srcip
                                , label   => "$srcip\n PVID: $vpn\n$vpns{$vpn}{NAME}"
                                , shape   => $shape
                                , URL       => "http://url.site/document#VLAN_$vpn"
                                , cluster => { name      => "$tron\n($trons{$tron}{IP})"
                                             , style     => $clustyle
                                             , fontname  => 'Arial Bold'
                                             , fillcolor => $clusfc
                                             }
                                );

                    next if defined $added{$vpn}{$dstip}{$srcip} and $added{$vpn}{$dstip}{$srcip}; # Only one pass

                    my $ping = undef;

                    if ($chuis{$sysObjectID}{name} eq 'ex4200-24p') {
                        $ping = join('', $telnet->cmd("$chuis{$sysObjectID}{chkcmd} routing-instance $vpns{$vpn}{R_INS} $dstip"));
                    } else {
                        $ping = join('', $telnet->cmd("$chuis{$sysObjectID}{chkcmd} $dstip"));
                    }

                    my $edgecolor = my $fillcolor = "$vpns{$vpn}{COLOR}";
                    my $edgestyle = 'solid';
                    $edgestyle = 'dotted' if $vpns{$vpn}{R_INS} eq 'voz';

                    if ($ping =~ /$chuis{$sysObjectID}{regexp}/sg) {
                        $added{$vpn}{$srcip}{$dstip} = 1;
                        print "\t($vpn) $srcip\t-> $dstip (OK)\n" unless $ARGV[0];
                    } else {
                        print "\t($vpn) $srcip\t-> $dstip (NOK!)\n" unless $ARGV[0];
                        $fillcolor = 'red';
                        $edgecolor = 'black';
                        $edgestyle = 'bold';
                    }

                    $g->add_node( $srcip
                                , fillcolor => $fillcolor
                                );

                    unless (defined $trons{$node}) {
                        print "\tAdded orphan node: ($vpn) $node $dstip\n" unless $ARGV[0];
                        $g->add_node( $dstip
                                    , label     => "$node ($dstip)\nPVID: $vpn\n$vpns{$vpn}{NAME}"
                                    , shape     => 'ellipse'
                                    , fillcolor => $fillcolor
                                    , URL       => "http://url.site/document#VLAN_$vpn"
                                    );
                    } else {
                        $g->add_node( $dstip
                                    , label     => "$dstip\n PVID: $vpn\n$vpns{$vpn}{NAME}"
                                    , fillcolor => $fillcolor
                                    , URL       => "http://url.site/document#VLAN_$vpn"
                                    );
                    }

                    $g->add_edge( $srcip => $dstip
                                , color => $edgecolor
                                , style => $edgestyle
                                );
                }
            }
        }
    }
    $telnet->close;
}

my $dir=$ENV{'PWD'};
my $date = scalar localtime();
my $runtime=(time - $^T);
$dir=$ARGV[0] if ($ARGV[0] and -d $ARGV[0]);

open (FH, ">$dir/troncales.png") || die "Can't redirect stdout";
print FH $g->as_png;
close (FH);

my $imagemap = $g->as_cmapx;
$imagemap =~ s/\\n/ /g;

open (FH, ">$dir/index.html") || die "Can't redirect stdout";
print FH <<EOF;
<html>
    <head>
        <title>Troncales // $date // ${runtime}s</title>
        <meta http-equiv="refresh" content=600>
    </head>
    <body>
        <a href="http://docu.host.com/resolveUid/e19511e04ca690c5eda6e862166cc89d">
            <img src="troncales.png" usemap="#Troncales"></a>
        </a>
        $imagemap
    </body>
</html>
EOF
close (FH);

`geeqie $dir/troncales.png&` unless $ARGV[0];

exit 0;
