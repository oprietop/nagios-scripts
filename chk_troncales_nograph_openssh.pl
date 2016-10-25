#!/usr/bin/perl -w

use warnings;
use strict;
use MIME::Base64;
use Net::OpenSSH;
#$Net::OpenSSH::debug |= 16; # Debug

my @warnings  = ();
my @criticals = ();

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
                    my ($srcip, $dstip) = ($vpns{$vpn}{NODES}{$tron}, $vpns{$vpn}{NODES}{$node});
                    my $flow = "[$tron] ($vpn) $srcip -> $dstip";
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

# Process the output files.
foreach my $result (sort @results) {
    my $out = decode_base64($result);
    open(FH, "<", "/tmp/$result") or die "Unable to read file: $!";
    local $/ = undef;
    my $cont = <FH>;
    close(FH);
    if ($cont =~ /$chuis{regexp}/sg) {
        print STDERR ">> $out (OK)\n"
    } else {
        print STDERR ">> $out (NOK!)\n";
        push (@criticals, "$out (NOK!)");
    }
    unlink "/tmp/$result";
}

# Print every abnormal output and exit appropiately.
my $date = scalar localtime();
my $runtime=(time - $^T);
print join("\n", @criticals);
print join("\n", @warnings);
print "OK (${runtime}s) <a href=\"http://documentation\" target=\"_blank\">documentation</a>\n" and exit 0;
exit 2 if @criticals;
exit 1 if @warnings;
