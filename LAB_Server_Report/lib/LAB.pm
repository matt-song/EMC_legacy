#!/usr/bin/perl
package LAB;
use strict;
use Data::Dumper;
use Term::ANSIColor;

my $DEBUG = 1;

sub getServerHASH
{
    my ($self, $serverlist) = @_;
    my $result = {};
    
    if ( ! -f $serverlist)
    {
        ECHO_ERROR('self', "Could not found Server List [$serverlist], exit",1);
    }
    open SERVERLIST,$serverlist or do { ECHO_ERROR('self',"Unable to read Server List [$serverlist], exit",1);};
    while (<SERVERLIST>) 
    {
        chomp(my $line = $_);
        next if ($line =~ /^#/);
        next if ($line =~ /^\s*$/);
        
        my ($IP,$TYPE,$COMMENT) = split(',',$line);
        if ($IP !~ /\d+\.\d+\.\d+\.\d+/)
        {
            ECHO_DEBUG('self',"not valid IP format for [$IP], skip..");
            next;
        }
        $result->{$IP}->{'type'} = $TYPE;
        $result->{$IP}->{'comment'} = $COMMENT;
    }
    #print Dumper $result;
    return $result;
}



sub printColor
{
    my ($self,$Color,$MSG) = @_;
    print color "$Color"; print "$MSG"; print color 'reset';
}
sub ECHO_DEBUG
{
    my ($self,$message) = @_;
    printColor('self', 'blue',"[DEBUG] $message"."\n") if $DEBUG;
}

# sub ECHO_WARN
# {
    # my ($self,$message) = @_;
    # printColor('yellow',"[WARNING] $message"."\n");
# }
# sub ECHO_INFO
# {
    # my ($self,$message) = @_;
    # printColor('self','green',"[INFO] $message"."\n");
# }
sub ECHO_ERROR
{
    my ($self, $Message,$ErrorOut) = @_;
    printColor('self','red',"[ERROR] $Message"."\n");
    if ($ErrorOut == 1){ exit(1);}else{return 1;}
}

1;