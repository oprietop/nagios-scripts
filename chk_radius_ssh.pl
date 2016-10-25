#!/usr/bin/perl
# nagios SSH multiplexer wrapper

use warnings;
use strict;
use Net::OpenSSH;
#$Net::OpenSSH::debug |= 16; # Debug

my %hosts = ( 'host1' => { CMD  => "radtest -t mschap user pass localhost 0 good1"
                         , OK   => 'Access-Accept'
                         , WARN => 'rejected'
                         }
            , 'host2' => { CMD => 'radtest user2 pass2 localhost 10 good2'
                         , OK  => 'RADIUS OK'
                         }
            );

# Initiate and keep a connection to each host.
my %conn = map { $_ => Net::OpenSSH->new( $_
                                        , port                  => 22
                                        , key_path              => "$ENV{HOME}/.ssh/id_rsa"
                                        , async                 => 1
                                        , timeout               => 10
                                        , master_stderr_discard => 1
                                        , master_opts           => [-o => "StrictHostKeyChecking=no"]
                                        )
               } keys %hosts;

# Launch commands to each host reusing the connection if needed.
my @pid = ();
my @results = ();
foreach my $host (keys %hosts) {
    print STDERR "# Connecting to '$host'\n";
    open my($fh), '>', "/tmp/$host" or die "Unable to create file: $!";
    my $pid = $conn{$host}->spawn( { stdout_fh => $fh
                                   , stderr_fh => $fh
                                   }
                                 , $hosts{$host}{CMD}
                                 );
    push(@pid, $pid) if $pid;
}

# Wait for all the commands to finish.
waitpid($_, 0) for @pid;

# Process the output files.
my @warnings  = ();
my @criticals = ();
foreach my $host (sort keys %hosts) {
    print STDERR "# Result from '$host'\n";
    my $slurp = do { local( @ARGV, $/ ) = "/tmp/$host" ; <> };
    unlink "/tmp/$host";
    print STDERR "$slurp\n";
    next if $slurp =~ m/$hosts{$host}{OK}/i;
    if ($hosts{$host}{WARN} and $slurp =~ /$hosts{$host}{WARN}/i) { 
        push (@warnings, "$host WARNING ($hosts{$host}{WARN})");
        next;
    }
    push (@criticals, "$host CRITICAL");
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
my $date = scalar localtime();
my $runtime=(time - $^T);
print "OK (${runtime}s)\n" and exit 0;
