#!/usr/bin/perl
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
my %opts; getopts('Dfi', \%opts);
my $DEBUG = $opts{'D'};   

my $SR_Number = &get_SR;
my $input = &get_input;

&generate_report($SR_Number, $input);

sub generate_report
{
    my ($SR,$input) = @_;
    my ($ver,$sn,$hostname,$model);
    ECHO_SYSTEM("Generating the report...");
    
    foreach my $line (split("^", $input))
    {
        chomp($line);
        $ver = $1 if ($line =~ /VERSION=Data Domain OS ([\d+\.+]*)-\d+/);
        $sn = $1 if ($line =~ /SYSTEM_SERIALNO=(.*)/);
        $hostname = $1 if ($line =~ /HOSTNAME=(.*)/);
        $model = $1 if ($line =~ /MODEL_NO=(.*)/);
    }
    
    ECHO_DEBUG("DDOS ver is [$ver]\nSN is [$sn]\nhostname is [$hostname]\nModel is [$model]");
    my $report = "
========== GENERAL INFO ==========

    SR Number:   $SR
    Hostname:    $hostname
    SerialNo:    $sn
    ModelNo:     $model
    Version:     $ver

========== PROBLEM DESCRYPTION ==========



========== CONCLUSION / ROOT CAUSE ==========



========== TROUBLESHOOTING DONE ==========



========== NEXT ACTION PLAN ==========



========== RELATED LOGS ==========



";  
    print $report;
}

sub get_input
{
    ECHO_SYSTEM("Please input the ASUP title");
    my $input;
    
    while (<STDIN>) 
    {
        last if /^$/;
        $input .= $_;
    }
    ECHO_DEBUG("the input is: [$input]");
    return $input;
}



sub get_SR
{
    ECHO_SYSTEM("Please input the SR number");
    chomp(my $SR = (<>) );
    ECHO_DEBUG("The SR is [$SR]");
    return $SR;    
}


### define function to make the world more beautiful ###
sub ECHO_SYSTEM
{
    my ($message) = @_;
    printColor('yellow',"$message"."\n");
}
sub ECHO_DEBUG
{
    my ($message) = @_;
    printColor('blue',"[DEBUG] $message"."\n") if $DEBUG;
}
sub ECHO_INFO
{
    my ($message, $no_return) = @_;
    printColor('green',"[INFO] $message");
    print "\n" if (!$no_return);
}
sub ECHO_ERROR
{
    my ($Message,$ErrorOut) = @_;
    printColor('red',"[ERROR] $Message"."\n");
    if ($ErrorOut == 1){ exit(1);}else{return 1;}
}
sub printColor
{
    my ($Color,$MSG) = @_;
    print color "$Color"; print "$MSG"; print color 'reset';
}
