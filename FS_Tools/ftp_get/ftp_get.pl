#!/usr/bin/perl
#################################################################
# Author:      Matt Song (matt.song@dell.com)                   #
# Create Date: 2017.06.14                                       #
# description: downloading the files on ftp site                #
#                                                               #
# Update at 2017.10.31: Added interactive mode and bug fix      #
#                                                               #
#################################################################
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
my %opts; getopts('Dfi', \%opts);
my $DEBUG = $opts{'D'};   
my $INTERACTION_MODE = $opts{'i'};

my $_FTP = "/usr/bin/ftp";
my $_WGET = "/usr/bin/wget";
my $file_list_hash = {};

my $ftp_info = &get_FTP_info();

&get_file_list($ftp_info);
print Dumper $file_list_hash if $DEBUG;

&get_target_file($ftp_info, $file_list_hash);

sub get_FTP_info
{
    my $ftp_info = {};
    
    if ($INTERACTION_MODE)
    {
        ### get ftp url ###
        ECHO_INFO("Please input the ftp server(default: ftp.emc.com):");
        chomp(my $ftp_server=(<>));
        $ftp_server = "ftp.emc.com" if (! $ftp_server);
        
        ECHO_INFO("Please input the ftp user name");
        chomp(my $ftp_user=(<>));
                
        ECHO_INFO("Please input the ftp password");
        chomp(my $ftp_password=(<>));
        
        $ftp_info->{'site'} = $ftp_server;
        $ftp_info->{'user'} = $ftp_user;
        $ftp_info->{'password'} = $ftp_password;    
    }
    else
    {
        ### get the ftp link ###
        ECHO_INFO("Please paste the ftp link here:");
        chomp(my $ftp_link=(<>));

        ## example: https://ftp.emc.com/action/login?domain=ftp.emc.com&username=ZIq7YicWL&password=757AatStS5
        ECHO_DEBUG("Get ftp link [$ftp_link]");
            
        ### get the ftp login info ###
        if ($ftp_link =~ /login\?domain=(.*)\&username=(\w+)\&password=(\w+)\s*$/)
        {
            $ftp_info->{'site'} = $1;
            $ftp_info->{'user'} = $2;
            $ftp_info->{'password'} = $3;    
                
        }
        else
        {
            ECHO_DEBUG("Get ftp info: [$1], [$2], [$3]");
            ECHO_ERROR("Invalid link [$ftp_link], please check!",1);
        }
    }
    
    ECHO_SYSTEM("
==============================
FTP site: $ftp_info->{'site'}
User:     $ftp_info->{'user'}
Password: $ftp_info->{'password'}
==============================
");

    return $ftp_info;    
}

sub get_file_list
{
    my ($ftp_info, $path)= @_;
    my $file_list;
       
    ### no path defined, should be 1st time call this function, getting file list from root folder
    if (! $path)  
    {   
        ECHO_INFO("Getting file list from FTP, please wait...\n");
        $file_list = &execute_ftp_command($ftp_info,"dir");
        ECHO_DEBUG("file list is [$file_list]");
       
        foreach my $line (split('^', $file_list))
        {
            chomp($line);
            next if ($line =~ 'Invalid command');
            ECHO_DEBUG("found line [$line]");
            
            ## example: drw-rw-rw-   1 user     group           0 Jun 13 23:36 folder with space
            if ($line =~  /([drwx-]+)\s+\d+\s+\w+\s+\w+\s+(\d+)\s+(\w+\s+\d+\s+[\d:]+)\s+(.*)$/ )
            {
                my $file_permission = $1;
                my $file_size = $2;
                my $file_mtime = $3;
                my $file_name = $4;
                my $file_path = "/$file_name";
                ECHO_DEBUG("found permission: [$file_permission], size: [$file_size], mtime: [$file_mtime], filename: [$file_name]");
                
                if ($file_permission =~ /^d/) ## is folder, call check_folder_structure
                {
                    ECHO_DEBUG("Found folder [$file_name], checking the files in there...");
                    &get_file_list($ftp_info,$file_path);
                }
                else
                {
                    $file_list_hash->{$file_path}->{'size'} = $file_size;
                    $file_list_hash->{$file_path}->{'mtime'} = $file_mtime;
                }
            }
        }
    }
    ### have path defined, checking the sub file under the folder..
    else
    {
        my $file_list = &execute_ftp_command($ftp_info, qq(cd \\"$path\\"\\ndir));
        foreach my $line (split('^', $file_list))
        {
            chomp($line);
            next if ($line =~ 'Invalid command');
            
            if ($line =~  /([drwx-]+)\s+\d+\s+\w+\s+\w+\s+(\d+)\s+(\w+\s+\d+\s+[\d:]+)\s+(.*)$/)
            {
                my $file_permission = $1;
                my $file_size = $2;
                my $file_mtime = $3;
                my $file_name = $4;
                my $file_path = "$path/$file_name";
                
                if ($file_permission =~ /^d/) ## is folder, call check_folder_structure
                {
                    ECHO_DEBUG("Found folder [$file_name], checking the files in there...");
                    &get_file_list($ftp_info,$file_path);
                }
                else
                {
                    $file_list_hash->{$file_path}->{'size'} = $file_size;
                    $file_list_hash->{$file_path}->{'mtime'} = $file_mtime;
                }
            }
        }
    }
}

sub get_target_file
{
    my ($ftp_info,$file_list_hash) = @_;
    my $index = {};
    
    ### show file list ###
    my $count = 0;
    foreach my $file (keys $file_list_hash)
    {
        $count++;
        
        my $file_name = $file;
        my $file_mtime = $file_list_hash->{$file}->{'mtime'};
        my $file_size = $file_list_hash->{$file}->{'size'};
        
        ECHO_SYSTEM("    [$count]\tFile:\t$file_name");
        ECHO_SYSTEM("    \tMTIME:\t[$file_mtime]\tSize: [$file_size]\n");
        
        $index->{$count}=$file;
    }
    
    ECHO_INFO("Please select the file you want to download, example: [1], [1-2], [1,3,4]");
    while (<STDIN>)
    {
        chomp(my $input = $_);
        my $target_list;
        
        
        if ($input =~ /^\d+$/)
        {
            if ($input > $count)
            {
                ECHO_ERROR("Input is out of range: input [$input], maxium [$count]"); 
                next; 
            }
            push @$target_list, $index->{$input};
            #print Dumper \@target_list if $DEBUG; 
            &download_file($ftp_info, $target_list, $file_list_hash);
            
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
                    push @$target_list, $index->{$id};
                }
                #print Dumper \@target_list if $DEBUG;
                &download_file($ftp_info, $target_list, $file_list_hash);
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
                push @$target_list, $index->{$id}; 
            }
            ### remove the duplicate item 
            my %hash = map { $_ => 1 } @$target_list;
            my $target_list_uniq;
            push @$target_list_uniq, $_ foreach (keys %hash);
                        
            #print Dumper \@target_list_uniq if $DEBUG;  
            &download_file($ftp_info, $target_list_uniq, $file_list_hash);
        }
        else
        {
            if (! $input)
            {
                ECHO_INFO("By :-)");
                exit;
            }
            else
            {
                ECHO_ERROR("Invalid input [$input], please retry!");
            }
        }
    ECHO_INFO("Please select the file you want to download, example: [1], [1-2], [1,3,4]");
    }
}

sub download_file
{
    my ($ftp_info, $file_list, $file_list_hash) = @_;
    
    print Dumper $file_list if $DEBUG; 
    foreach my $file (@$file_list)
    {
        ECHO_INFO("Downloading the file [$file]...");
        my $command = qq($_WGET -r -nc -nd 'ftp://$ftp_info->{'user'}:$ftp_info->{'password'}\@$ftp_info->{'site'}$file');
        my $result = run_command($command);
    }
}


sub execute_ftp_command
{
    my ($ftp_info,$ftp_command) = @_;
    my $ftp_site = $ftp_info->{'site'};
    my $ftp_user = $ftp_info->{'user'};
    my $ftp_pass = $ftp_info->{'password'};
    
    my $command = qq(echo -e "\\nquote USER $ftp_user\\nquote PASS $ftp_pass\\n$ftp_command" | $_FTP -n $ftp_site 2>&1); 
    ECHO_DEBUG("The ftp command is [$command]");
    
    my $result = &run_command($command);
    foreach my $line (split('^',$result))
    {
        ECHO_ERROR("Unable to execute ftp command [$ftp_command], please check the code!",1) if ($line =~ /Requested action not taken. File unavailable/);
        ECHO_ERROR("Unable to execute ftp command [$ftp_command], please check the credential!",1) if ($line =~ /Address already in use/);
    }
    return $result;
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
