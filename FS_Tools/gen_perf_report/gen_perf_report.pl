#!/usr/bin/perl
#################################################################
# Author:      Matt Song (matt.song@dell.com)                   #
# Create Date: 2017.06.19                                       #
# description: generate performance report based on asup        #
# DDOS tested: 5.6,5.7,6.0,6.1                                  #
#                                                               #
# Update @ Aug 15th, 2017:                                      #
# add -a option so we can targeting ASUP file manually          #
#                                                               #
#################################################################
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
my %opts; getopts('hDb:o:a:', \%opts);

my $_LS = "/bin/ls";
my $_CAT = "/bin/cat";
my $_GREP = "/bin/grep";
my $_HEAD = "/usr/bin/head";
my $_AWK = "/usr/bin/awk";
my $_SED = "/bin/sed";
my $_TAIL = "/usr/bin/tail";
my $_ECHO = "/bin/echo";
my $_DATE = "/bin/date";
my $_MKDIR = "/bin/mkdir";
my $_BASENAME = "/usr/bin/basename";

my $DEBUG = $opts{'D'};   
my $bundle = ($opts{'b'})?$opts{'b'}:".";  ## path of bundle, if not set, use current folder
my $asup_file = $opts{'a'};
my $asup_folder = "$bundle/ddr/var/support/" if (! $asup_file);
my $OPTION = ($opts{'o'})? $opts{'o'}:'ALL';

&print_help if $opts{'h'};

### Start working ###
&check_input;
ECHO_INFO("checking the files under [$bundle/]...\n");

### first get the ASUP list ###
my $asup_hash = &get_asup_list($bundle);

### generated the time period of system show performance report, and let user choose which one want to print ###
my $target_asup = &print_duration_list($asup_hash);

### generate the hash for raw data ###
my $raw_data_hash = gen_perf_hash($target_asup, $asup_hash);

### Generate the report based on user's input ###
generate_report($raw_data_hash, $asup_hash, $target_asup);

ECHO_SYSTEM("\nAll done, bye :\)");

### Functions ###

sub generate_report
{
    my ($raw_data,$asup_hash,$target_asup) = @_;
    
    foreach my $asup_ID (@$target_asup)
    {
        my $asup = $asup_hash->{$asup_ID};
        ECHO_DEBUG("Generating report based on asup [$asup]...");
                
        if ($OPTION =~ /^ALL$/)
        {
            ECHO_DEBUG("The option was set to [$OPTION], generating CSV and graph file under current folder based on [$asup]...");            
            &generate_CSV($raw_data->{$asup},$asup);
            #&generate_graph($data_hash,$asup);
        }
        elsif ($OPTION =~ /^CSV$/)
        {
            ECHO_DEBUG("The option was set to [$OPTION], generating CSV report under current folder based on [$asup]...");
            &generate_CSV($raw_data->{$asup},$asup);
        }
        elsif ($OPTION =~ /^GRAPH$/)
        {
            ECHO_DEBUG("The option was set to [$OPTION], generating graph under current folder based on [$asup]...");            
            # &generate_graph($raw_data->{$asup},$asup);
        }
    }
}

sub generate_CSV
{
    my ($raw_data, $asup) = @_;
    
    ### creating the working folder ###
    my $current_folder = ".";
    my $folder_name = &run_command( qq($_ECHO "perf_report_`$_DATE +%F`_$$"));
    my $report_folder = "$current_folder/$folder_name";
    if ( ! -d $report_folder)
    {
        ECHO_INFO("Creating working folder [$report_folder]...");
        &run_command( qq($_MKDIR -p $report_folder) );
        ECHO_ERROR("unable to create report folder [$report_folder], exit!",1) if ( ! -d $report_folder);
    }
    
    ### generate file name
    my $hostname = &get_host_name($asup);
    (my $start_date = $raw_data->{'1'}->{'date'}) =~ s/\//\_/g;
    my $basename_asup = run_command("$_BASENAME $asup");
    my $csv_report = "perf_report_${hostname}_${start_date}_${basename_asup}.csv";
    ECHO_DEBUG("the cvs file name is [$csv_report]");
    
    ### generating the csv file ###
    open CSV,'>',"$report_folder/$csv_report" or do { ECHO_ERROR("Unable to write output to [$csv_report], please check!",1); };
    print CSV "Date,Read throughput,Write throughput,REPL in,REPL out,REPL precomp in,REPL precomp out,gcomp,lcomp,read stream,write stream,REPL in stream,REPL out stream,CPU,DISK\n";
    foreach my $id (sort{$a <=> $b} keys $raw_data)
    {
        print CSV "$raw_data->{$id}->{'date'} ";
        print CSV "$raw_data->{$id}->{'time'},";
        print CSV "$raw_data->{$id}->{'read_throughput'},";
        print CSV "$raw_data->{$id}->{'write_thoughput'},";
        print CSV "$raw_data->{$id}->{'repl_net_in'},";
        print CSV "$raw_data->{$id}->{'repl_net_out'},";
        print CSV "$raw_data->{$id}->{'repl_precomp_in'},";
        print CSV "$raw_data->{$id}->{'repl_precomp_out'},";
        print CSV "$raw_data->{$id}->{'gcomp'},";
        print CSV "$raw_data->{$id}->{'lcomp'},";
        print CSV "$raw_data->{$id}->{'stream_rd'},";
        print CSV "$raw_data->{$id}->{'stream_wr'},";
        # print CSV "$raw_data->{$id}->{'stream_rdplus'},";
        # print CSV "$raw_data->{$id}->{'stream_wrplus'},";
        print CSV "$raw_data->{$id}->{'stream_repl_in'},";
        print CSV "$raw_data->{$id}->{'stream_repl_out'},";
        # print CSV "$raw_data->{$id}->{'fs_process'},";
        print CSV "$raw_data->{$id}->{'cpu_load'},";
        print CSV "$raw_data->{$id}->{'disk_load'}\n";
    }
    close CSV;
    ECHO_INFO("Generated performance report under [$report_folder/$csv_report]...");
}

sub check_input
{
    if ($OPTION !~ /^ALL$|^CSV$|^GRAPH$/)
    {
        ECHO_ERROR("The option [$OPTION] has not supported yet!");
        &print_help;
    }
    if ($asup_file)
    {
        ECHO_ERROR("Can not find ASUP file [$asup_file], please check and rertry",1) if ( ! -f $asup_file);
    }
}

sub print_help
{
    my $program = run_command("basename $0");
    ECHO_SYSTEM("
    USAGE: $program [-b <path_0f_bundle>] [-o <option>] [-D]
           $program -a <ASUP File>
        
       -h:  print help message.
       
       -b:  the root path of the support bundle. will use current folder if not specified.
       
       -a:  manually target the ASUP file.
       
       -o:  which kind of output you want to save, will use ALL if not specified
            1. CSV      generate CSV file for performance report
            2. GRAHP    generate the graph based on raw data. [NOT SUPPORTED YET]
            3. ALL      generate both CSV file and graph picture 
            
       -D:  Enable DEBUG mode.
       
    EXAMPLE:
    
        1. generated both CSV based on bundle in current folder
           # $program
       
        2. generate both CVS and graph based on bundle under /path/to/the/bundle
           # $program -b /path/to/the/bundle
       
        3. generated CSV report based on bundle under /path/to/the/bundle 
           # $program -a /path/to/the/ASUP   
");
    exit 1;
}

### get the raw data based on system show perf output
### refer to the link: http://iweb.datadomain.com/eweb/pmwiki/pmwiki.php/DataDomain/SystemShowPerformanceCommand
sub gen_perf_hash
{
    my ($target_asup_ID,$asup_hash) = @_;
    
    my $perf_hash;
    foreach my $asup_ID (@$target_asup_ID)
    {
        my $asup = $asup_hash->{$asup_ID};
        ECHO_DEBUG("Generating raw data from asup [$asup]...");
        my $DDOS_ver = get_ddos_verion($asup);
    
        ##### DDOS 5.6 and 5.7 #####
        if ($DDOS_ver =~ /^5.6.*$|^5.7.*$/)
        {
            ECHO_DEBUG("working as $DDOS_ver mode...");
            my $raw_data = &run_command( qq($_SED -n '/===  SYSTEM SHOW PERFORMANCE  ===/,/===  SYSTEM SHOW PERFORMANCE FSOP  ===/p' ${asup_folder}${asup} | $_GREP "^[0-9]") );
            
            my $id = 0;
            foreach my $line (split'^', $raw_data)
            {
                if ($line =~ /^([\d\/]+)\s+([\d\:]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s*\/\s*([\d\.]+)\s+([\d\.]+)\s*\/\s*([\d\.]+)\s+\d+\s+[\d\.]+\s+[\d\.]+\s*\/\s*[\d\.]+\s+[\d\.]+\s*\/\s*[\d\.]+\s+([\d\.]+)\s+([\d\.]+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*(\d+)\s*\/\s*(\d+)\s+\d+\s*\/\s*\d+\s+([\w\-]+)\s+(\d+)\s*\/\s*[\d\[\]]+\s+(\d+)\[\d+\]\s+/)
                {
                    $id++;
                    ECHO_DEBUG("$1|$2|$3|$4|$5|$6|$7|$8|$9|$10|$11|$12|$13|$14|$15|$16|$17|$18|$19");

                    $perf_hash->{$asup}->{$id}->{'date'} = $1;
                    $perf_hash->{$asup}->{$id}->{'time'} = $2;
                    $perf_hash->{$asup}->{$id}->{'read_throughput'} = $3;
                    $perf_hash->{$asup}->{$id}->{'write_thoughput'} = $4;
                    $perf_hash->{$asup}->{$id}->{'repl_net_in'} = $5;
                    $perf_hash->{$asup}->{$id}->{'repl_net_out'} = $6;
                    $perf_hash->{$asup}->{$id}->{'repl_precomp_in'} = $7;
                    $perf_hash->{$asup}->{$id}->{'repl_precomp_out'} = $8;
                    $perf_hash->{$asup}->{$id}->{'gcomp'} = $9;
                    $perf_hash->{$asup}->{$id}->{'lcomp'} = $10;
                    $perf_hash->{$asup}->{$id}->{'stream_rd'} = $11;
                    $perf_hash->{$asup}->{$id}->{'stream_wr'} = $12;
                    $perf_hash->{$asup}->{$id}->{'stream_rdplus'} = $13;
                    $perf_hash->{$asup}->{$id}->{'stream_wrplus'} = $14;
                    $perf_hash->{$asup}->{$id}->{'stream_repl_in'} = $15;
                    $perf_hash->{$asup}->{$id}->{'stream_repl_out'} = $16;
                    $perf_hash->{$asup}->{$id}->{'fs_process'} = $17;
                    $perf_hash->{$asup}->{$id}->{'cpu_load'} = $18;
                    $perf_hash->{$asup}->{$id}->{'disk_load'} = $19;
                }
            }
        }
        ##### DDOS 6.0 and 6.1 #####
        elsif($DDOS_ver =~ /^6.0.*$|^6.1.*$/)
        {
            ECHO_DEBUG("working as 6.0 mode...");
            my $raw_data = &run_command( qq($_SED -n '/===  SYSTEM SHOW PERFORMANCE LEGACY VIEW  ===/,/===  SYSTEM SHOW PERFORMANCE CUSTOM-VIEW  ===/p' ${asup_folder}${asup} | $_GREP "^[0-9]") );
            
            my $id = 0;
            foreach my $line (split'^', $raw_data)
            {
                #ECHO_DEBUG("working on line [$line]..");
                if ($line =~ /^([\d\/]+)\s+([\d\:]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s*\/\s*([\d\.]+)\s+([\d\.]+)\s*\/\s*([\d\.]+)\s+\d+\s+[\d\.\%]+\s+[\d\.]+\s*\/\s*[\d\.]+\s+[\d\.]+\s*\/\s*[\d\.]+\s+([\d\.]+)\s+([\d\.]+)\s+[\d\%]+\s+[\d\%]+\s+[\d\%]+\s+[\d\%]+\s+[\d\%]+\s+(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*\d+\s*\/\s*\d+\s+([\w\-]+)\s+(\d+)\%\s*\/\s*[\d\%\[\]]+\s+(\d+)\%\s*\[/)
                {
                    $id++;
                    ECHO_DEBUG("$1|$2|$3|$4|$5|$6|$7|$8|$9|$10|$11|$12|$13|$14|$15|$16|$17|$18|$19");

                    $perf_hash->{$asup}->{$id}->{'date'} = $1;
                    $perf_hash->{$asup}->{$id}->{'time'} = $2;
                    $perf_hash->{$asup}->{$id}->{'read_throughput'} = $3;
                    $perf_hash->{$asup}->{$id}->{'write_thoughput'} = $4;
                    $perf_hash->{$asup}->{$id}->{'repl_net_in'} = $5;
                    $perf_hash->{$asup}->{$id}->{'repl_net_out'} = $6;
                    $perf_hash->{$asup}->{$id}->{'repl_precomp_in'} = $7;
                    $perf_hash->{$asup}->{$id}->{'repl_precomp_out'} = $8;
                    $perf_hash->{$asup}->{$id}->{'gcomp'} = $9;
                    $perf_hash->{$asup}->{$id}->{'lcomp'} = $10;
                    $perf_hash->{$asup}->{$id}->{'stream_rd'} = $11;
                    $perf_hash->{$asup}->{$id}->{'stream_wr'} = $12;
                    $perf_hash->{$asup}->{$id}->{'stream_rdplus'} = $13;
                    $perf_hash->{$asup}->{$id}->{'stream_wrplus'} = $14;
                    $perf_hash->{$asup}->{$id}->{'stream_repl_in'} = $15;
                    $perf_hash->{$asup}->{$id}->{'stream_repl_out'} = $16;
                    $perf_hash->{$asup}->{$id}->{'fs_process'} = $17;
                    $perf_hash->{$asup}->{$id}->{'cpu_load'} = $18;
                    $perf_hash->{$asup}->{$id}->{'disk_load'} = $19;
                }
            }
        }
        else ### default one ###
        {
            ECHO_INFO("The script has not support [$DDOS_ver] yet, trying default mode...");
            my $raw_data = &run_command( qq($_SED -n '/===  SYSTEM SHOW PERFORMANCE  ===/,/===  SYSTEM SHOW PERFORMANCE FSOP  ===/p' ${asup_folder}${asup} | $_GREP "^[0-9]" | $_SED 's/%//g' )  );
            
            my $id = 0;
            foreach my $line (split'^', $raw_data)
            {
                #if ($line =~ /^([\d\/]+)\s+([\d\:]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s*\/\s*([\d\.]+)\s+([\d\.]+)\s*\/\s*([\d\.]+)\s+\d+\s+[\d\.]+\s+[\d\.]+\s*\/\s*[\d\.]+\s+[\d\.]+\s*\/\s*[\d\.]+\s+([\d\.]+)\s+([\d\.]+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*(\d+)\s*\/\s*(\d+)\s+\d+\s*\/\s*\d+\s+([\w\-]+)\s+(\d+)\s*\/\s*[\d\[\]]+\s+(\d+)\[\d+\]\s+/)

                if ($line =~ /^([\d\/]+)\s+([\d\:]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s*\/\s*([\d\.]+)\s+([\d\.]+)\s*\/\s*([\d\.]+)\s+\d+\s+[\d\.]+\s+[\d\.]+\s*\/\s*[\d\.]+\s+[\d\.]+\s*\/\s*[\d\.]+\s+([\d\.]+)\s+([\d\.]+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*\/\s*(\d+)\s*(\d+)\s*\/\s*(\d+)/)

                {
                    $id++;
                    ECHO_DEBUG("$1|$2|$3|$4|$5|$6|$7|$8|$9|$10|$11|$12|$13|$14|$15|$16|$17|$18|$19");

                    $perf_hash->{$asup}->{$id}->{'date'} = $1;
                    $perf_hash->{$asup}->{$id}->{'time'} = $2;
                    $perf_hash->{$asup}->{$id}->{'read_throughput'} = $3;
                    $perf_hash->{$asup}->{$id}->{'write_thoughput'} = $4;
                    $perf_hash->{$asup}->{$id}->{'repl_net_in'} = $5;
                    $perf_hash->{$asup}->{$id}->{'repl_net_out'} = $6;
                    $perf_hash->{$asup}->{$id}->{'repl_precomp_in'} = $7;
                    $perf_hash->{$asup}->{$id}->{'repl_precomp_out'} = $8;
                    $perf_hash->{$asup}->{$id}->{'gcomp'} = $9;
                    $perf_hash->{$asup}->{$id}->{'lcomp'} = $10;
                    $perf_hash->{$asup}->{$id}->{'stream_rd'} = $11;
                    $perf_hash->{$asup}->{$id}->{'stream_wr'} = $12;
                    $perf_hash->{$asup}->{$id}->{'stream_rdplus'} = $13;
                    $perf_hash->{$asup}->{$id}->{'stream_wrplus'} = $14;
                    $perf_hash->{$asup}->{$id}->{'stream_repl_in'} = $15;
                    $perf_hash->{$asup}->{$id}->{'stream_repl_out'} = $16;
                    $perf_hash->{$asup}->{$id}->{'fs_process'} = $17;
                    $perf_hash->{$asup}->{$id}->{'cpu_load'} = $18;
                    $perf_hash->{$asup}->{$id}->{'disk_load'} = $19;
                }
            }
        }
    }
    #print Dumper $perf_hash if $DEBUG;
    return $perf_hash;
}

sub print_duration_list
{
    my $asup_hash = shift;
    ECHO_INFO("Checking the ASUP list...\n");    
    
    foreach my $id (sort {$a<=>$b} keys $asup_hash )
    {
        my $asup = $asup_hash->{$id};
        ECHO_DEBUG("checking report for [$asup]");
        my $DDOS_ver = get_ddos_verion($asup);
        
        ##### DDOS 5.7 #####
        if ($DDOS_ver =~ /^5.6.*$|^5.7.*$/)
        {
            ECHO_DEBUG("DDOS is $DDOS_ver...");
            my $start_time = &run_command( qq($_SED -n '/===  SYSTEM SHOW PERFORMANCE  ===/,/===  SYSTEM SHOW PERFORMANCE FSOP  ===/p' ${asup_folder}${asup} | $_GREP "^[0-9]" | $_HEAD -1 | $_AWK '{print \$1,\$2}') );
            my $end_time = &run_command( qq($_SED -n '/===  SYSTEM SHOW PERFORMANCE  ===/,/===  SYSTEM SHOW PERFORMANCE FSOP  ===/p' ${asup_folder}${asup} | $_GREP "^[0-9]" | $_TAIL -1 | $_AWK '{print \$1,\$2}') );
        
            ECHO_DEBUG("ASUP: [$asup], begin: [$start_time], end: [$end_time]");
            ECHO_SYSTEM("   [$id]\t\t$asup\t\tfrom [$start_time] to [$end_time]");
        }
        ##### DDOS 6.0 and 6.1 #####
        elsif ($DDOS_ver =~ /^6.0.*$|^6.1.*$/)
        {
            ECHO_DEBUG("DDOS is 6.0...");
            my $start_time = &run_command( qq($_SED -n '/===  SYSTEM SHOW PERFORMANCE LEGACY VIEW  ===/,/===  SYSTEM SHOW PERFORMANCE CUSTOM-VIEW  ===/p' ${asup_folder}${asup} | $_GREP "^[0-9]" | $_HEAD -1 | $_AWK '{print \$1,\$2}') );
            my $end_time = &run_command( qq($_SED -n '/===  SYSTEM SHOW PERFORMANCE LEGACY VIEW  ===/,/===  SYSTEM SHOW PERFORMANCE CUSTOM-VIEW  ===/p' ${asup_folder}${asup} | $_GREP "^[0-9]" | $_TAIL -1 | $_AWK '{print \$1,\$2}') );
        
            ECHO_DEBUG("ASUP: [$asup], begin: [$start_time], end: [$end_time]");
            ECHO_SYSTEM("   [$id]\t\t$asup\t\tfrom [$start_time] to [$end_time]");
        
        }
        ##### Default #####
        else
        {
            my $start_time = &run_command( qq($_SED -n '/===  SYSTEM SHOW PERFORMANCE  ===/,/===  SYSTEM SHOW PERFORMANCE FSOP  ===/p' ${asup_folder}${asup} | $_GREP "^[0-9]" | $_HEAD -1 | $_AWK '{print \$1,\$2}') );
            my $end_time = &run_command( qq($_SED -n '/===  SYSTEM SHOW PERFORMANCE  ===/,/===  SYSTEM SHOW PERFORMANCE FSOP  ===/p' ${asup_folder}${asup} | $_GREP "^[0-9]" | $_TAIL -1 | $_AWK '{print \$1,\$2}') );
        
            ECHO_DEBUG("ASUP: [$asup], begin: [$start_time], end: [$end_time]");
            ECHO_SYSTEM("   [$id]\t\t$asup\t\tfrom [$start_time] to [$end_time]");
        }
    }
    
    #### get input ###
    print "\n";
    
    if ($asup_file)
    {
        my $target_list = [0];
        return $target_list;
    }
    
    ECHO_INFO("Please select the file you want to check, example: [1], [1-2], [1,3,4]");
    while (<STDIN>)
    {
        chomp(my $input = $_);
        my $target_list;
        my $count = keys $asup_hash;
                        
        if ($input =~ /^\d+$/)
        {
            if ($input > $count)
            {
                ECHO_ERROR("Input is out of range: input [$input], maxium [$count]"); 
                next; 
            }
            push @$target_list, $input;
            return $target_list;
        }
        elsif($input =~ /^(\d+)-(\d+)$/)
        {
            my $start = $1;
            my $end = $2;
            if ($start < $end)
            {
                for (my $id=$start; $id <= $end; $id++) 
                {
                    if ($id > $count)
                    {
                        ECHO_ERROR("Input is out of range: target [$id], maxium [$count]"); 
                        next; 
                    }
                    push @$target_list, $id;
                }
                return $target_list;
            }
            else
            {
                ECHO_ERROR("Wrong range: [$1 to $2]") ;
                next;
            }
        }
        elsif($input =~ /^\d+[\d\,]+\d+$/)
        {
            foreach my $id (sort{$a <=> $b} split(',', $input))
            {
                if ($id > $count)
                {
                    ECHO_ERROR("Input is out of range: target [$id], maxium [$count]"); 
                    next; 
                }
                push @$target_list, $id; 
            }
            ### remove the duplicate item 
            my %hash = map { $_ => 1 } @$target_list;
            my $target_list_uniq;
            push @$target_list_uniq, $_ foreach (keys %hash);
            #print Dumper $target_list_uniq if $DEBUG;          
            
            return $target_list_uniq;
        }
        else
        {
            ECHO_ERROR("Invalid input [$input], please retry!");
        }
    ECHO_INFO("Please select the file you want to check, example: [1], [1-2], [1,3,4]");
    }

}

sub get_host_name
{
    my $asup = shift;
    my $hostname = run_command( qq($_CAT ${asup_folder}${asup} | $_GREP -A20 "==========  GENERAL INFO  ==========" | $_GREP "^HOSTNAME=" | $_AWK -F'=' '{print \$2}') );
    
    ECHO_DEBUG("the hostname in ASUP [$asup] is [$hostname]");
    
    $hostname = ($hostname)? $hostname:"UNKNOWN_DD";
    return $hostname;   
}

sub get_ddos_verion
{
    my $asup = shift;
    my $DDOS_VER;
    
    my $DDOS_VER_LINE = &run_command( qq($_CAT ${asup_folder}${asup} | $_GREP -A20 "==========  GENERAL INFO  ==========" | $_GREP "^VERSION=" ) );
    
    if ($DDOS_VER_LINE =~ /^VERSION=Data Domain OS (.*)\-\d+/ )
    {
        $DDOS_VER = $1;
        ECHO_DEBUG("Found DDOS version: [$DDOS_VER]");
    }
    else
    {
        ECHO_ERROR("Unable to get DDOS version from ASUP file [$asup], skip");
    }
    return $DDOS_VER;
}

sub get_asup_list
{
    my $bundle = shift;
    my $asup_hash = {};
    
    if ($asup_file)
    {
        $asup_hash = { '0' => $asup_file };
        return $asup_hash;
    }
    if (-d $asup_folder)
    {
        my $asup_list = &run_command( qq($_LS -t $asup_folder | $_GREP autosupport 2>/dev/null) );
        ECHO_DEBUG("Found ASUP list [$asup_list]");
        ECHO_ERROR("No ASUP was found under path $asup_folder, please check!",1) if (! $asup_list);
        
        foreach my $asup (split('^', $asup_list) )
        {
            chomp($asup);
            if ($asup =~ /autosupport\.?(\d*)/)
            {
                my $id = ($1) ? $1:'0';
                $asup_hash->{$id} = $asup;
            }
            else
            {
                next;
            }
        }
    }
    else
    {
        ECHO_ERROR("Cannot found asup folder [$asup_folder], exit...",1);
    }
    print Dumper $asup_hash if $DEBUG;
    return $asup_hash;   
}

sub run_command
{
    my $cmd = shift;
    ECHO_DEBUG("will run command [$cmd]..");
    chomp(my $result = `$cmd` );
    my $rc = "$?";
    if ($rc)
    {
        ECHO_ERROR("Failed to excute command [$cmd], return code is $rc"); 
        return $rc;
    }
    else
    {
        ECHO_DEBUG("Command excute successfully, return code [$rc]");
        #ECHO_DEBUG("the result is [$result]");
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
