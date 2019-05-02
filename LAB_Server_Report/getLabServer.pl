#!/usr/bin/perl
#################################################################
# Author:      Matt Song (matt.song@dell.com)                   #
# Create Date: 2015.02.28                                       #
# description: Generate the report for LAB server list          #
#                                                               #
# Update @ Aug 27th, 2018:                                      #
# adding new column for server IPMI port                        #
#                                                               #
#################################################################
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
use CGI;
#use CGI::Session;
my %opts; getopts('Dc:', \%opts);

my $DEBUG = $opts{'D'};
my $ServerList = ($opts{'c'})?$opts{'c'}:'./conf/ServerList.conf';
my $OutFile = './htdoc/html/labserverlist.html';
my $EXPECT = './bin/ssh.sh';
my $_PING = '/bin/ping';
my $_DATE = '/bin/date';

### Check the Configuration file and Generate the server HASH
my $ServerHASH = getServerHASH($ServerList);
#print Dumper $ServerHASH;
my $Result = generateReport($ServerHASH);
print Dumper $Result;
my $HTML_PAGE = generateHTML($Result);

open HTML,'>',$OutFile or do {ECHO_ERROR('Unable to write HTML file',1)};
print HTML $HTML_PAGE;

sub generateHTML
{
    my $result = shift;
    my $HTML = '';
    
    my $cgi = CGI->new;
    #$HTML .= $cgi->header( -charset => 'utf-8');
    $HTML .= $cgi->start_html(
            -title  => 'EMC DataDomain Shanghai Lab',
            -style  => [
                        {'src'=>'../css/style.css'},
                       ],
    );

    $HTML .= qq(
<link rel='stylesheet prefetch' href='https://cdnjs.cloudflare.com/ajax/libs/materialize/0.97.0/css/materialize.min.css'>
<link rel='stylesheet prefetch' href='https://fonts.googleapis.com/icon?family=Material+Icons'>

<div class="row">
    <div id="admin" class="col s12">
        <div class="card material-table">
        
            <div class="table-header">
                <span class="table-title">Welcome to EMC DataDomain Shanghai Lab</span>
            </div>
        
            <table id="sortable">
            <thead>
                <tr id="table-head">
                    <th id="head" width=10%>Model</th>
                    <th id="head" width=15%>IP Addr</th>
                    <th id="head" width=10%>Status</th>
                    <th id="head" width=10%>FS status</th>
                    <th id="head" width=10%>DDOS version</th>
                    <th id="head" width=10%>Repl Set</th>
                    <th id="head" width=10%>Working Repl</th>
                    <th id="head" width=10%>FC Card</th>
                    <th id="head" width=15%>IPMI Addr</th>
                </tr>
            </thead>
            <tbody>
);
    foreach my $server (sort keys %$result)
    {
        my $DD_IP = $server;
        my $DD_STATUS = $result->{$server}->{'status'};
        my $DD_VER = $result->{$server}->{'version'};
        my $DD_MOD = $result->{$server}->{'model'};
        my $DD_FS = $result->{$server}->{'filesystem'};
        my $DD_REPL_SET = $result->{$server}->{'repl_set'};
        my $DD_REPL_NUM = $result->{$server}->{'repl_num'};
        my $DD_FC = $result->{$server}->{'fc'};
        my $DD_IPMI = $result->{$server}->{'ipmi'};
        
        $DD_IP = qq(<a href="http://$DD_IP/ddem/" target="_blank">$DD_IP</a>);
        $DD_STATUS = ($DD_STATUS eq 'Online')?qq(<font color=\"green\">$DD_STATUS</font>):qq(<font color=\"red\">$DD_STATUS</font>);
        $DD_FS = ($DD_FS eq 'Online')?qq(<font color="green">$DD_FS</font>):qq(<font color="red">$DD_FS</font>);
        $DD_REPL_SET = ($DD_REPL_SET eq 'Yes')?qq(<font color="green">Yes</font>):$DD_REPL_SET;
        $DD_REPL_NUM = ($DD_REPL_NUM > 0)?qq(<font color="green">$DD_REPL_NUM</font>):$DD_REPL_NUM;
        $DD_FC = ($DD_FC eq 'Yes')?qq(<font color="green">$DD_FC</font>):$DD_FC;
        $DD_IPMI = qq(<a href="https://$DD_IPMI/" target="_blank">$DD_IPMI</a>);
        
        $HTML .= qq(
                <tr>
                <td>$DD_MOD</td>
                <td>$DD_IP</td>
                <td>$DD_STATUS</td>
                <td>$DD_FS</td>
                <td>$DD_VER</td>
                <td>$DD_REPL_SET</td>
                <td>$DD_REPL_NUM</td>
                <td>$DD_FC</td>
                <td>$DD_IPMI</td>
                </tr>        
);
    }

    $HTML .= qq(
            </tbody>
            </table>
);
    
    ### Add modified date into html ###
    #chomp(my $time = `$_DATE "+%D %H:%M:%S"`);
    chomp(my $time = `$_DATE`);
    $HTML .= qq(
    </div>
    <div id="time">
        <p>Last update: $time</p>
    </div>
</div>
<script src='http://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.3/jquery.min.js'></script>
<script src='http://tablesorter.com/__jquery.tablesorter.min.js'></script>
<script src="../js/index.js"></script>
);
    $HTML .= $cgi->end_html;
    print $HTML if $DEBUG;
    return $HTML;
}

sub generateReport
{
    my $config = shift;
    #print Dumper $config;
    my $result = {};
    
    foreach my $server (keys %$config)
    {
        if ($config->{$server}->{'type'} == 'DD')
        {
            my ($DDOS_VER, $DD_MODEL, $DD_FSStatus, $DD_FC, $DD_IPMI);
        
            ECHO_INFO("===== Working on [$server] =====");
            my $user = $config->{$server}->{'user'};
            my $pw = $config->{$server}->{'password'};
            
            ### check if DD has offline ###
            my $DD_Status = 'Online';
            my $DD_isOnline_CHECK = system("$_PING -c2 -q $server > /dev/null");
            if ($DD_isOnline_CHECK)
            {
                ECHO_ERROR("DD is offline, skip");
                $result->{$server}->{'status'} = 'Offline';
                $result->{$server}->{'version'} = '-';
                $result->{$server}->{'model'} = $config->{$server}->{'comment'};
                $result->{$server}->{'filesystem'} = '-';
                $result->{$server}->{'fc'} = '-';
                $result->{$server}->{'repl_set'} = '-';
                $result->{$server}->{'repl_num'} = '-';
                $result->{$server}->{'ipmi'} = $config->{$server}->{'ipmi'};;
                next;
            }
            ECHO_INFO("[$server] is [$DD_Status]");
            
            ### DDOS Verion ###
            my $DDOS_VER_OUTPUT = SSH_EXPECT($server,$user,$pw,'uname');
            $DDOS_VER = ( $DDOS_VER_OUTPUT =~ /Data Domain OS ([\d\.]+)-/ )?$1:'n/a';
            ECHO_INFO("DDOS Release is [$DDOS_VER]");
            
            ### DD Module ###
            if ($config->{$server}->{'comment'} =~ /DDVE|DDMC/)
            {
                $DD_MODEL = $config->{$server}->{'comment'};
            }
            else
            {
                my $DD_MODEL_OUTPUT = SSH_EXPECT($server,$user,$pw,'system show modelno');
                $DD_MODEL = ( $DD_MODEL_OUTPUT =~ /Model number: ([\w\d]+)/ )?$1:$config->{$server}->{'comment'};
            }
            ECHO_INFO("DDR Model No is [$DD_MODEL]");

            ### REPL context number ###
            if ( $config->{$server}->{'comment'} ne "DDMC" )
            {
                my $DD_REPL_OUTPUT = SSH_EXPECT($server,$user,$pw,'replication show config');

                my $count = 0;
                foreach ( split(/^/,$DD_REPL_OUTPUT) )
                {
                    chomp(my $line = $_);
                    if ($line =~ /^\d+\s+/)
                    {
                        ECHO_DEBUG("Find replicatoin [$line]");
                        $count++;
                    }
                }
                if ($count)
                {
                    $result->{$server}->{'repl_set'} = 'Yes';
                }
                else
                {
                    $result->{$server}->{'repl_set'} = 'No';
                }
            }
            else
            {
                $result->{$server}->{'repl_set'} = '-';
            }
            ECHO_INFO("DDR replication configured status is [$result->{$server}->{'repl_set'}]");

            ### active replication context ###
            if ( $config->{$server}->{'comment'} ne "DDMC" )
            {
                my $DD_REPL_STATE_OUTPUT = SSH_EXPECT($server,$user,$pw,'replication status');
                my $count = 0;
                foreach (split(/^/,$DD_REPL_STATE_OUTPUT) )
                {
                    chomp(my $line=$_);
                    if ($line =~ /^\d+\s+/)
                    {
                        ECHO_DEBUG("Find replicatoin [$line]");
                        my ($ctx,$dest,$enabled,$connection) = split(/\s{2,}/,$line);
                        ECHO_DEBUG("get the value: $ctx,$dest,$enabled,$connection");
                        $count++ if ($connection ne "disconnected");
                    }
                }
                $result->{$server}->{'repl_num'} = $count;
            }
            else
            {
                $result->{$server}->{'repl_num'} = '-';
            }
            ECHO_INFO("DDR working replicatoin pair is [$result->{$server}->{'repl_num'}]");        

            ### FS Status ###
            my $DD_FSStatus_OUTPUT = SSH_EXPECT($server,$user,$pw,'fi st');
            $DD_FSStatus = ( $DD_FSStatus_OUTPUT =~ /The filesystem is enabled and running/i )?'Online':'Offline';
            $DD_FSStatus = '-' if ($config->{$server}->{'comment'} =~ /^DDMC$/);
            ECHO_INFO("FileSystem status is [$DD_FSStatus]");
            
            ### FC Card ###
            my $DD_FC_OUTPUT = SSH_EXPECT($server,$user,$pw,'system show ports');
            $DD_FC = ( $DD_FC_OUTPUT =~ /\s+FC-Tgt\s+/i )?'Yes':'No';
            ECHO_INFO("FC card status is [$DD_FC]");
            
            $result->{$server}->{'status'}=$DD_Status;
            $result->{$server}->{'version'}=$DDOS_VER;
            $result->{$server}->{'model'}=$DD_MODEL;
            $result->{$server}->{'filesystem'}=$DD_FSStatus;
            $result->{$server}->{'fc'}=$DD_FC;
            $result->{$server}->{'ipmi'} = $config->{$server}->{'ipmi'};;
        }
    }
    return $result;
}

sub SSH_EXPECT
{
    my ($server,$user,$password,$cmd) = @_;
    my $result;
    
    ECHO_DEBUG("$EXPECT $server $user $password '$cmd'");
    
    if ((! $server)|| (! $user) || (! $password) || (! $cmd))
    {
        ECHO_ERROR("Missing parameter for SSH command, exit")
    }
    else
    {
        $result = `$EXPECT $server $user $password "$cmd"`;
        #chomp($result);
        ECHO_DEBUG("$result");
        return $result;
    }
}

sub getServerHASH
{
    my $serverlist = shift;
    my $result = {};
    
    ECHO_DEBUG("Checking server list in conf file [$serverlist]");
    if ( ! -f $serverlist)
    {
        ECHO_ERROR("Could not found Server List [$serverlist], exit",1);
    }
    open SERVERLIST,$serverlist or do { ECHO_ERROR("Unable to read Server List [$serverlist], exit",1);};
    while (<SERVERLIST>) 
    {
        chomp(my $line = $_);
        next if ($line =~ /^#/);
        next if ($line =~ /^\s*$/);
        
        ### format: IP,TYPE(DD=DataDomain,SW=Switch,LI=LinuxServer),user,password,comment,IPMI
        ### remove the format checking since the conf file was set by admin and admin should alway check the format before proceed the script.
       
        my ($IP,$TYPE,$USER,$PW,$COMMENT,$IPMI) = split(',',$line);
        ECHO_DEBUG("Get: [$IP],[$TYPE],[$USER],[$PW],[$COMMENT],[$IPMI]...");
     
        $result->{$IP}->{'type'} = $TYPE;
        $result->{$IP}->{'comment'} = $COMMENT;
        $result->{$IP}->{'user'} = $USER;
        $result->{$IP}->{'password'} = $PW;
        $result->{$IP}->{'ipmi'} = $IPMI;
    }
    #print Dumper $result;
    return $result;
}
sub ECHO_DEBUG
{
    my ($message) = @_;
    printColor('blue',"[DEBUG] $message"."\n") if $DEBUG;
}
sub ECHO_INFO
{
    my ($message) = @_;
    printColor('green',"[INFO] $message"."\n");
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

