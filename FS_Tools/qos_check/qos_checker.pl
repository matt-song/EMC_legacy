#!/usr/bin/perl
#################################################################
# Author:      Matt Song (matt.song@dell.com)                    #
# Create Date: 2016.11.04                                       #
# description: Use this script to analysis the QOS logs         #
#################################################################
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
use CGI;
#use CGI::Session;
my %opts; getopts('Df:s:e:', \%opts);

my $DEBUG = $opts{'D'};             ## debug mode
my $bundle = $opts{'f'};            ## path to the support bundle, use current path if not specified 
$bundle = '.' if (!$bundle);

### getting input time, transfer to timestamp ###
my $start_time = $opts{'s'};
my $end_time = $opts{'e'};
my @input_processing_result = &check_input_time($start_time, $end_time);
my $start_timestamp = @input_processing_result[0];
my $end_timestamp = @input_processing_result[1];
ECHO_DEBUG("Start: [$start_time], StartStamp: [$start_timestamp], End: [$end_time], EndStamp: [$end_timestamp]");

## binary setting ##
my $_DATE = "/bin/date";

## start working ##
my @target = &check_log_folder($bundle);
&get_target_logs(@target);





### check the input time and return the time stamp ###
sub check_input_time
{
    my ($start,$end) = @_;
    my ($start_stamp, $end_stamp);
    
    unless ($start)
    {
        ECHO_ERROR("No start time input, please check!",1);   
    }
    else
    {
        $start_stamp = run_command( qq(date -d "$start" +%s) );
    }
    
    if ($end)
    {
        $end_stamp = run_command( qq(date -d "$end" +%s) );
    }
    else
    {
        $end_stamp = 0;
    }
        
    ECHO_DEBUG("Start timestampe: [$start_stamp], End timestamp: [$end_stamp]");
    my @result = ($start_stamp,$end_stamp);
    return @result;
}

### check the target qos log and get logs for target time ###
sub get_target_logs
{
    my @target = @_;
    print Dumper @target if $DEBUG;
    my $target_TimeStamp = $target[0];
    my $target_log = $target[1];
    
    my $_GREP = get_grep_bin($target_log);
    
    ECHO_INFO("Checking time [$target_TimeStamp] under log file [$target_log]...");
    

    # my $result;
    
    #ECHO_INFO("Please input the peroid you would like to check, example: input 30 to check the 30 min before/after [$]")    
    #chomp my $peroid = (<STDIN>); 

    my $start_time_line = &run_command( qq($_GREP '****** dd_iosched stats @ ' $bundle/ddr/var/log/debug/platform/$target_log) );
    ECHO_DEBUG("Found below time: [$start_time_line]");
    
    
    
    
    
    
}



### check the bundle folder and get the target log file and time. ###
sub check_log_folder
{
    my $bundle = shift;
    ECHO_DEBUG("checking support bundle under [$bundle]..");
    
    ECHO_SYSTEM('
==================================================================================================
welcome to the QOS check, if you have any question, please feel free to contact matt.song@dell.com
==================================================================================================
    ');
    
    #ECHO_INFO("please input the start date: [yyyy-mm-dd] ",1);
    #chomp(my $selected_id = <STDIN>);
    
    ## find all qos logs ##
    ECHO_INFO("Searching qos log under path [$bundle/]...\n");
    my $qos_log_list = &run_command("ls -t $bundle/ddr/var/log/debug/platform/ | grep qos.info");
    ECHO_ERROR("Unable to get qos log under path [$bundle/ddr/var/log/debug/platform/], please check!",1) if ($qos_log_list =~ /^\d+$/);
    ECHO_DEBUG("Find below QOS log: [\n$qos_log_list\n]");
    my @qos_logs;
    foreach(split('^',$qos_log_list))
    {
        chomp(my $line = $_);
        push(@qos_logs,$line);
    }
    
    ## get start/end time of each log ##
    my $time_list_of_qos = &get_time_of_qos("$bundle/ddr/var/log/debug/platform", @qos_logs);
    
    ## print the qos log list ##   
    ECHO_INFO("Found below log files:");
    foreach my $id ( sort {$a<=>$b} keys $time_list_of_qos)
    {
        my $log_file = $time_list_of_qos->{$id}->{'log'};
        my $start_time = $time_list_of_qos->{$id}->{'start'};
        my $end_time = $time_list_of_qos->{$id}->{'end'};
        
        ### this part need be enhance to make output more pretty
        printf("    [%2s] Log Name: [%14s]\tStart time: [$start_time]\tEnd time: [$end_time]\n",$id,$log_file)
        #ECHO_SYSTEM("[$id]\tLog Name: [$log_file]\tStart time: [$start_time]\tEnd time: [$end_time]");        
    }
    print "\n";    
    
    while (1)
    {
        ECHO_INFO("Please input the time you would like to check, using whatever format which acceptable for \"date -d\" command");
        ECHO_INFO("Example:     Aug 08 2017 12:34");
        ECHO_INFO("             2017/08/08 12:34");
        ECHO_INFO("             2017-08-08 12:34");
        ECHO_INFO("Time you would like to check: ",1);
      
        chomp(my $input_time = <STDIN>);
        chomp(my $input_timestamp = `$_DATE -d "$input_time" +%s 2>/dev/null`);
            
        ### checking the input ###
        if ($input_timestamp !~ /^\d+$/)
        {
            ECHO_ERROR("Unable to get timestampe by using [$input_time], please check and retry..."); 
            next;
        }
        ### get the target qos log ###
        foreach (keys $time_list_of_qos)
        {
            my $log_start_timestamp = $time_list_of_qos->{$_}->{'start_stamp'};
            my $log_end_timestamp = $time_list_of_qos->{$_}->{'end_stamp'};
            
            ECHO_DEBUG("input: [$input_timestamp], start: [$log_start_timestamp], end: [$log_end_timestamp]");
                
            if ( ($input_timestamp >= $log_start_timestamp) && ($input_timestamp <= $log_end_timestamp) )
            {
                my $target_log = $time_list_of_qos->{$_}->{'log'};
                ECHO_INFO("The time [$input_time] is in log [$target_log]");
                my @target = ($input_timestamp, $target_log);
                return @target;
            }
        }
        ### exit if no log was found ###
        ECHO_ERROR("Can not find any file contain the log of [$input_time], exit",1); 
    }  
}


sub check_qos_log
{
    my $qos_log = shift;
    
    ## check the time list ##
    my $_GREP = get_grep_bin($qos_log);
    my $time_list = &run_command( qq($_GREP '****** dd_iosched stats @ ' $qos_log ) );
    ECHO_DEBUG("Find the time list as [$time_list]");
    
    return 0;
}

sub get_time_of_qos
{
    my ($log_path, @log_list) = @_;
    my $result = {};
    my $count = 0;
    
    foreach my $log (@log_list)
    {
        ECHO_DEBUG("checking qos log [$log_path/$log]");
        my $_GREP = get_grep_bin($log);
                
        ### example: ****** dd_iosched stats @ Fri Oct 28 04:01:01 CST 2016 ********
        my $start_time_line = &run_command( qq($_GREP '****** dd_iosched stats @ ' $log_path/$log | head -1) );
        my $end_time_line = &run_command( qq($_GREP '****** dd_iosched stats @ ' $log_path/$log | tail -1) );
        
        my $start_time = $1 if ($start_time_line =~ /\* dd_iosched stats \@ \w+ ([\w\s\:]+) \*/);
        my $end_time = $1 if ($end_time_line =~ /\* dd_iosched stats \@ \w+ ([\w\s\:]+) \*/);
        chomp(my $start_stamp = `$_DATE -d "$start_time" +%s`);
        chomp(my $end_stamp = `$_DATE -d "$end_time" +%s`);
                
        ECHO_DEBUG("Log: [$log], Start time: [$start_time|$start_stamp], End time: [$end_time|$end_stamp]");
        
        $result->{$count}->{'log'} = $log;
        $result->{$count}->{'start'} = $start_time;
        $result->{$count}->{'end'} = $end_time;
        $result->{$count}->{'start_stamp'} = $start_stamp;
        $result->{$count}->{'end_stamp'} = $end_stamp;
        $count++;
    }
    printColor('blue',Dumper $result) if $DEBUG; 
    #print Dumper $result;
    return $result;
}

sub get_grep_bin
{
    my $log = shift;
    
    my $_GREP = "/bin/grep";
    $_GREP = "/bin/zgrep" if ($log =~ /\.gz$/);
    return $_GREP;
}

sub run_command
{
    my $cmd = shift;
    ECHO_DEBUG("will run command [$cmd]..");
    chomp(my $result = `$cmd`);
    my $rc = "$?";
    if ($rc)
    {
        ECHO_ERROR("Failed to excute command [$cmd], return code is $rc"); 
        return $rc;
    }
    else
    {
        ECHO_DEBUG("Command excute successfully");
        return $result;        
    }
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
