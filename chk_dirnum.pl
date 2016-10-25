#!/usr/bin/perl
# https://community.emc.com/thread/148249
# Get all the nfs mounted dirs and report the ones with a large num of dirs.

use strict;
use warnings;
use POSIX;
use Storable;# store, retrieve
use Cwd 'abs_path';

my $fullpath  = abs_path($0);
my $critdirs  = 60000;
my @criticals = ();
my $warndirs  = 50000;
my @warnings  = ();

# Disable stdout buffering
$|++;

# Restore and use our saved hash if we have one
if (-f "$fullpath.hash") {
    my $href = retrieve("$fullpath.hash");
    for my $path (sort keys %{$href}) {
        printf ( STDERR "%-6.6s %s (%ss)\n" , $href->{$path}->{dcount} , $path , $href->{$path}->{secs});
    if ($href->{$path}->{dcount} > $critdirs) {
        push (@criticals, "$path has $href->{$path}->{dcount} dirs.");
        } elsif ($href->{$path}->{dcount} > $warndirs) {
        push (@warnings, "$path has $href->{$path}->{dcount} dirs.");
        }
    }
} else {
    print STDERR "First run...\n";
}

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
exit 2 if @criticals;
print join("\n", @warnings);
exit 1 if @warnings;
print "OK\n";

# Fork the process and return to the shell
fork and exit 0;

# Allow one instance of the script running at once
use Fcntl qw(LOCK_EX LOCK_NB);
open HIGHLANDER, ">>/tmp/perl_$0_highlander" or die "Cannot get lockfile: $!";
{
    flock HIGHLANDER, LOCK_EX | LOCK_NB and last;
    die "Script already running!";
}

# Read /etc/mtab and get all the nfs mounted filesystems
open (MTAB, '<', '/etc/mtab') or die "Error opening '/etc/mtab': $!";
my %paths = map { $_ => 1 } map { /\s(\S+)\s+nfs\s/ } <MTAB>;
print STDERR "Got ".(keys %paths)." paths to check in background...\n";
close MTAB;

# Get all the directories for each path
for my $path (sort keys %paths) {
    next unless -d $path;
    my $starttime = time;
    my $dcount = 0;
    my $dh;
    return if ! opendir($dh, $path);
    while (readdir($dh)) {
        $dcount++ if -d _ # http://www.perlmonks.org/?node_id=613625
    }
    closedir $dh;
    $paths{$path} = { dcount   => $dcount
                    , startime => $starttime
                    , endtime  => time
                    , secs     => time - $starttime
                    };
}

# Serialize our hash
store(\%paths, "$fullpath.hash") or die "Can't store '$fullpath.hash': $!";
