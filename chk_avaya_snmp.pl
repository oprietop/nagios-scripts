#!/usr/bin/perl -w
# Nagios script for checking Avaya VSP/ERS devices via snmp

use strict;
use warnings;
use SNMP;
use Storable;
use Cwd 'abs_path';
use Data::Dumper;

print "Usage: $0 <host/s>\n" and exit 1 unless @ARGV;

# Editable Vars
my $host      = $ARGV[0];
my $community = 'public';
my ($wcpu, $wmem, $wtemp) = (60, 60, 40);
# Fixed Vars
my @warnings  = ();
my @criticals = ();
my ($hostname, $cpu, $mem, $temp, $adjs) = ('Null', 0, 0, 0, 0);
my $fullpath  = abs_path($0);
my %oids      = ( '.1.3.6.1.4.1.2272.1.63.1.10'     => { 'OID' => 'rcIsisHostName'                 } # String
                , '.1.3.6.1.4.1.2272.1.63.10.1.3'   => { 'OID' => 'rcIsisAdjHostName'              } # Table
                , '.1.3.6.1.4.1.2272.1.85.10.1.1.2' => { 'OID' => 'rcKhiSlotCpuCurrentUtil'        } # %CPU)
                , '.1.3.6.1.4.1.2272.1.85.10.1.1.8' => { 'OID' => 'rcKhiSlotMemUtil'               } # %MEM
                , '.1.3.6.1.4.1.2272.1.212.1'       => { 'OID' => 'rcSingleCpSystemCpuTemperature' } # Celsius
                # ERS
                , '.1.3.6.1.4.1.45.1.6.3.8.1.1.5.3'  => { 'OID' => 'cpuLast1Minute' } # %
                , '.1.3.6.1.4.1.45.1.6.3.8.1.1.12.3' => { 'OID' => 'memTotal'       } # MB
                , '.1.3.6.1.4.1.45.1.6.3.8.1.1.13.3' => { 'OID' => 'memAvailable'   } # MB
                , '.1.3.6.1.4.1.45.1.6.3.7.1.1.5.5'  => { 'OID' => 'envTemp'        } # Half Degree Celsius
                );

# Do the SNMP stuff
my @VarBinds =();
push @VarBinds, new SNMP::Varbind([$_]) foreach keys %oids;
my $VarList = new SNMP::VarList(@VarBinds);
my $session = new SNMP::Session( 'DestHost'   => $host
                               , 'Community'  => $community
                               , 'Version'    => '2c' # No bulkwalk on v1
                               , 'UseNumeric' => 1   # Return dotted decimal OID
                               );
my $result = $session->bulkwalk(0, 1, $VarList);

# Traverse our snmp results pupulating our working hash
my $i = 0;
my %new_data = ();
for my $vbarr (@$result) {
    my $oid = $$VarList[$i++]->tag();
    push(@{ $new_data{$oids{$oid}{OID}}{VAL} }, $_->val) foreach @{ $vbarr };
}

# Serialize our array if not already stored to keep track of adjacency changes
my $savefile  = "${fullpath}_${host}.data";
if (keys %new_data and not -f $savefile) {
    store(\%new_data, $savefile);
    print STDERR "Creating $savefile file and exiting!\n";
    exit 0;
}

# Retrieve our saved array to compare to.
my %old_data = %{ retrieve($savefile) } if -f $savefile;
my @new_adjs = sort @{ $new_data{rcIsisAdjHostName}{VAL} };
my @old_adjs = sort @{ $old_data{rcIsisAdjHostName}{VAL} };

# Check VSP stuff
($hostname, $cpu, $mem, $temp, $adjs ) = ( $new_data{rcIsisHostName}{VAL}[0]
                                         , $new_data{rcKhiSlotCpuCurrentUtil}{VAL}[0]
                                         , $new_data{rcKhiSlotMemUtil}{VAL}[0]
                                         , $new_data{rcSingleCpSystemCpuTemperature}{VAL}[0]
                                         , scalar @new_adjs
                                         );
push (@warnings, "[$host] VSP Cpu usage: $cpu%")    if $cpu  and $cpu  > $wcpu;
push (@warnings, "[$host] VSP Memory usage: $mem%") if $mem  and $mem  > $wmem;
push (@warnings, "[$host] VSP Temperature: $tempº") if $temp and $temp > $wtemp;
print STDERR "VSP CPU: $cpu% MEM: $mem% TEMP: $temp\n" if $cpu;

# Check ERS stuff
if ( $new_data{cpuLast1Minute}{VAL} ) {
    $i = 0;
    foreach my $slot ( sort @{ $new_data{cpuLast1Minute}{VAL} } ) {
        $i++;
        my $ers_cpu  = $new_data{cpuLast1Minute}{VAL}[0];
        push (@warnings, "[$host] ERS Slot $i Cpu usage: $ers_cpu%") if $ers_cpu  > $wcpu;
        my $ers_mem  = sprintf( "%.0f", ($new_data{memAvailable}{VAL}[0]*100)/$new_data{memTotal}{VAL}[0]);
        push (@warnings, "[$host] ERS Slot $i Memory usage: $ers_mem%") if $ers_mem  > $wmem;
        my $ers_temp = sprintf( "%.0f", ($new_data{envTemp}{VAL}[0]/2));
        push (@warnings, "[$host] ERS Slot $i Temperature: $ers_tempº") if $ers_temp  > $wtemp;
        print STDERR "ERS Slot $i [ CPU: $ers_cpu% MEM: $ers_mem% TEMP: $ers_tempº ]\n";
    }
}

# Check Adjacencies
my %count = ();
my @diff = ();
$count{$_}++ foreach (@new_adjs, @old_adjs);
foreach my $ap (keys %count) {
    push(@diff, $ap) unless $count{$ap} == 2;
}
push (@warnings, "[$host] Missing/New Adjacencies: [ ".join(', ', @diff)." ]\n") if @diff;

# Print every abnormal output and exit appropiately.
print join("\n", @criticals);
print join("\n", @warnings);
exit 2 if @criticals;
exit 1 if @warnings;
print "Adjancencies: $adjs [ ".join(', ', @new_adjs)." ]\n";
exit 0;
