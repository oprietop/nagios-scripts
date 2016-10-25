#!/usr/bin/perl
# Check graphite metrics and supervisor status

use strict;
use warnings;
use File::Find; # find()

my @warnings  = ();
my @criticals = ();
my %hash      = ();
my $dir       = "/opt/graphite_storage/whisper";
my $hostname  = qx(hostname);
chomp($hostname);

# Convert seconds to Human Readable
sub seconds2HR($) {
    my $seconds = shift;
    return sprintf ( "%.1d Days, %.2d:%.2d:%.2d"
                   , $seconds/86400
                   , $seconds/3600%24
                   , $seconds/60%60
                   , $seconds%60
                   ) if $seconds or return 0;
}

# Populate our hash with the wsp files and his access time.
sub wanted {
    my $file = $File::Find::name;
    return unless -f $file;
    my @stats = stat($file); # http://perldoc.perl.org/functions/stat.html
    my $atime = time()-$stats[9];
    if (my ($path) = $file =~ m<$dir/(.+?)/[^/]+wsp$>) {
        return if $path =~ /graphite/;
        $hash{$path} = $atime if not $hash{$1} or $hash{$1} > $atime;
    }
}


# Check for not accessed metrics on the last 6 hours
print STDERR "\n# Checking metrics\n\n";
find (\&wanted, $dir);
map {delete $hash{$_} if $hash{$_} < 21600} keys %hash; # 21600sec = 6 hours
print STDERR "OK\n" unless keys %hash;
foreach my $file (sort keys %hash) {
    print STDERR "'$file' not updated since ".&seconds2HR($hash{$file})."\n";
    push (@warnings, "'$file' not updated since ".&seconds2HR($hash{$file})."\n");
}

# Check the supervisor processes.
print STDERR "\n# Checking processes\n\n";
my $output = qx(supervisorctl status);
#chomp($output);
print STDERR $output;
while ($output =~ /(\S+)\s+(\S+)\s+pid/sg) {
    push (@warnings, "The process '$1' is on state '$2'") if $2 ne "RUNNING";
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "OK\n" and exit 0;
