#!/usr/bin/perl
# Check all Smokeping's RRDs for lost packets over a number timeticks

use strict;
use warnings;

use File::Find qw(find);
use RRDs;
use POSIX qw(floor);
use Cwd 'abs_path';

my @warnings   = ();
my @criticals  = ();
my $dir        = '/var/lib/smokeping/';
my $uri        = 'http://smokeping.host/cgi-bin/smokeping.cgi?target=';
my $match      = '';     # Match the RRDs that matches that string
my $ignore     = 'EXT_'; # Ignore the RRDs that matches that string
my $ticks      = 3;      # Every tick = 5 minutes, must be 1 at least
my $loss       = 9;      # Average lost packets to care about
my $total_loss = 0;
my $fullpath   = abs_path($0);


sub logprint {
    my $text = shift or return;
    my $now = scalar localtime();
    open(LOG, ">> $fullpath.log") || die "Can't redirect stdout";
    print LOG "$now $text\n";
    close(LOG);
    return print $text;
}

sub wanted {
    my $file = $File::Find::name;
    my $valid_name = $1 if $file =~ /^$dir(.+?)\.rrd$/ or return;
    $valid_name =~ s/\//\./g;
    $valid_name =~ s/~\w+//g;

    return if $file !~ /$match/;
    return if $file =~ /$ignore/;
    my $lastupdatetime = RRDs::last($file);

    # We won't care on files older than our range
    my $diff = (time - $lastupdatetime);
    my $range = (300*$ticks); # ticks to seconds
    return if $diff > $range;

    # Fetch info
    my ($start, $step, $ds_names, $data) = RRDs::fetch($file,"AVERAGE","-s", $lastupdatetime - $range,"-e","now");

    # Get an array with the lost packets on each tick
    my @results = grep { defined $_ } map { @{$_}[1] } @{$data};

    # Sum the results and calculate the rounded down average
    my ($sum, $floor) = (0, 0);
    $sum += $_ foreach @results;
    $floor = floor(($sum/$ticks));
    $total_loss += $floor;;

    # Complain if we meet the pachet loss value
    push (@warnings, "<u><b><a href=\"${uri}${valid_name}\" target=\"_blank\">$valid_name</a></b></u> lost $floor average packets on the last ".($range/60)." minutes") if $floor >= $loss;
}

# Do Stuff
find(\&wanted, $dir);

# Print results and return the appropiate exit code
logprint join("\n", @criticals);
logprint join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
logprint "OK ($total_loss packets lost)\n" and exit 0;
