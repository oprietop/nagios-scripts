#!/usr/bin/perl -w

use warnings;
use strict;
use MIME::Base64;
use Net::OpenSSH;
use GraphViz;
#$Net::OpenSSH::debug |= 16; # Debug

my %chuis=( user   => 'user'
          , pass   => 'pass'
          , chkcmd => 'ping ttl 1 bypass-routing rapid'
          , regexp => ', 0% packet loss'
          );

my %trons=( 'TR1' => { IP   => '6.6.6.18'
                     , PORT => '22'
                     }
          , 'TR2' => { IP   => '6.6.6.10'
                     , PORT => '22'
                     }
                     }
          );

my %vpns=( 1111 => { NAME  => 'Data Link'
                   , R_INS => 'data'
                   , NODES => { 'TR1' => '192.168.101.17'
                              , 'TR2' => '192.168.101.18'
                              }
                   }
         , 222  => { NAME  => 'Voice Link'
                   , NODES => { 'TR1' => '192.168.102.17'
                              , 'TR2' => '192.168.102.18'
                   , R_INS => 'voice'
                              }
                   }
         , 333  => { NAME  => 'External Link'
                   , NODES => { 'TR1' => '192.168.103.17'
                              , 'TR2' => '192.168.103.18'
                   , R_INS => 'external'
                              }
                   }
         );

# Initiate and keep a connection to each host.
my %conn = map { $_ => Net::OpenSSH->new( $trons{$_}{IP}
                                        , port    => $trons{$_}{PORT} || 22
                                        , user    => $chuis{user}
                                        , passwd  => $chuis{pass}
                                        , async   => 1
                                        , timeout => 5
                                        , master_opts      => [-o => "StrictHostKeyChecking=no"]
                                        , default_ssh_opts => ['-oConnectionAttempts=0']
                                        ) } keys %trons;

# Launch commands to each host reusing the connection.
my @pid;
my @results= ();
foreach my $tron (sort {rand() <=> 0.5} keys %trons) {
    foreach my $vpn (sort {rand() <=> 0.5} keys %vpns) {
        if ($vpns{$vpn}{NODES}{$tron}) {
            foreach my $node (keys %{$vpns{$vpn}{NODES}}) {
                if ($node ne $tron) {
                    my ($name, $srcip, $dstip) = ($vpns{$vpn}{NAME}, $vpns{$vpn}{NODES}{$tron}, $vpns{$vpn}{NODES}{$node});
                    my $flow = "$node;$tron;$name;$vpn;$srcip;$dstip";
                    my $encoded_flow = encode_base64($flow);
                    open my($fh), '>', "/tmp/$encoded_flow" or die "Unable to create file: $!";
                    push(@results, $encoded_flow);
                    my $pid = $conn{$tron}->spawn( { stdout_fh => $fh
                                                   , stderr_fh => $fh
                                                   }
                                                 , "$chuis{chkcmd} routing-instance $vpns{$vpn}{R_INS} $dstip"
                                                 );
                    push(@pid, $pid) if $pid;
                }
            }
        }
    }
}

# Wait for all the commands to finish.
waitpid($_, 0) for @pid;

# Throw fancy pastel colors
sub random_colors {
    my ($r, $g, $b) = map { int(rand(128)) + 64 } 1 .. 3;
    my $lum = ($r * 0.3) + ($g * 0.59) + ($b * 0.11);
    my $bg = sprintf("#%02x%02x%02x", $r, $g, $b);
    my $fg = $lum < 128 ? "white" : "black";
    return ($bg, $fg);
}

# Create the graphviz object
my $g = GraphViz->new( name     => 'Troncales'
                     , rankdir  => 'TB'
                     , node     => { shape     => 'box'
                                   , style     => 'filled'
                                   , fillcolor => 'lightgray'
                                   , color     => 'black'
                                   , fontname  => 'terminus'
                                   , fontsize  => 7
                                   }
                     , edge     => { color     => 'black'
                                   , fontname  => 'terminus'
                                   }
                     );

# Process the output files.
my %added=();
foreach my $result (sort @results) {
    my $out = decode_base64($result);
    open(FH, "<", "/tmp/$result") or die "Unable to read file: $!";
    local $/ = undef;
    my $cont = <FH>;
    my ($node,$tron, $name, $vpn, $srcip, $dstip) = split(';', $out);
    close(FH);

    my ($edgecolor, $edgestyle) = ('black', 'dashed');
    my ($fillcolor, $fontcolor ) = random_colors();

    $added{$vpn}{$srcip}{$dstip} = 1;
    $g->add_node( $srcip
                , label   => "$vpns{$vpn}{NAME}\nPVID: $vpn\n$srcip"
                , URL     => "http://plone/resolveUid/xxxxx#VLAN_$vpn"
                , cluster => { name      => "$tron\n($trons{$tron}{IP})"
                             , style     => 'filled'
                             , fontname  => 'Arial Bold'
                             }
                );
    next if defined $added{$vpn}{$dstip}{$srcip} and $added{$vpn}{$dstip}{$srcip}; # Only one pass

    if ($cont =~ /$chuis{regexp}/sg) {
        $added{$vpn}{$srcip}{$dstip} = 1;
    } else {
        ($edgecolor , $fillcolor, $edgestyle) = ('red', 'red', 'bold');
    }

    my $shape = 'box';
    $shape = 'ellipse' unless defined $trons{$node};

    $g->add_node( $dstip
                , label   => "$node\nPVID: $vpn\n$dstip"
                , shape     => $shape
                , fillcolor => $fillcolor
                , fontcolor => $fontcolor
                , URL       => "http://plone/resolveUid/xxxxx#VLAN_$vpn"
                );

    $g->add_node( $srcip
                , fillcolor => $fillcolor
                , fontcolor => $fontcolor
                );

    $g->add_edge( $srcip => $dstip
                , style  => $edgestyle
                , color  => $edgecolor
                );

    unlink "/tmp/$result";
}

my $dir=$ENV{'PWD'};
my $date = scalar localtime();
my $runtime=(time - $^T);
$dir=$ARGV[0] if ($ARGV[0] and -d $ARGV[0]);

open (FH, ">$dir/out.png") || die "Can't redirect stdout";
print FH $g->as_png;
close (FH);

my $imagemap = $g->as_cmapx;
$imagemap =~ s/\\n/ /g;

open (FH, ">$dir/index.html") || die "Can't redirect stdout";
print FH <<EOF;
<html>
    <head>
        <title>Point to Point status // $date // ${runtime}s</title>
        <meta http-equiv="refresh" content=600>
    </head>
    <body>
        <a href="http://plone/resolveUid/yyyyy"_blank">
            <img src="out.png" usemap="#Troncales"></a>
        </a>
        $imagemap
    </body>
</html>
EOF
close (FH);

exit 0;
