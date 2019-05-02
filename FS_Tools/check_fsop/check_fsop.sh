#!/bin/bash
############################################################################
# Created by Matt Song at Feb 6th 2018                                     #
# Use this script to find the lookup/create/remove/close count in ddfs log #
############################################################################

### define the file system log folder ###
bundle_folder=$1;

if [ "x$bundle_folder" == "x" ]; 
then
    fs_log_folder="./";
else
    fs_log_folder="$bundle_folder/ddr/var/log/debug";
fi

echo "Checking the file system log under [$fs_log_folder]..."

### if in wrong folder, then exit and post an error ###
fs_log_count=`ls -tr $fs_log_folder | grep ddfs.info | wc -l`
if [ $fs_log_count -eq 0 ]
then
    echo "Unable to find any ddfs.info in folder [$fs_log_folder], please try again."
    echo "Usage: `basename $0`"
    echo "       `basename $0` </path/to/bundle>"
    exit
fi

### create temp folder under /tmp/ ###

temp_folder="/tmp/check_fsop_tmp.$$"
echo "creating the temp folder [$temp_folder]..."
mkdir -p $temp_folder

### go through the file system log and find the count of FSOP ###

for i in `ls -tr $fs_log_folder | grep ddfs.info`; 
do
    echo "checking file system log [$i]..."
    
    ### find the grep binary per the file type ###
    _GREP="/bin/grep"
    is_gz=`cat ${fs_log_folder}/${i} | grep ".gz" | wc -l`;
    [ $is_gz -gt 0 ] && _GREP="/bin/zgrep"
    
    ### filter all fsop log ###    
    for op in lookup create remove close; 
    do
        if [ $op == "lookup" ]
        then
            $_GREP fm_dm1_lookup_by_handle ${fs_log_folder}/${i} | grep Open >> $temp_folder/lookup.log
            elif [ $op == "create" ]
        then
            $_GREP fm_dm1_open ${fs_log_folder}/${i} | grep Create: >> $temp_folder/create.log
        elif [ $op == "remove" ]
        then
            $_GREP fm_dm1_remove ${fs_log_folder}/${i} | grep Remove: >> $temp_folder/remove.log
        elif [ $op == "close" ]
        then
            $_GREP fm_dm1_close_handle ${fs_log_folder}/${i} | grep Close >> $temp_folder/close.log
        fi
    done
done

### generate the report ###

echo "Calculating the counts of each FSOP..."

total_lookup=`cat $temp_folder/lookup.log | wc -l`
total_create=`cat $temp_folder/create.log | wc -l`
total_remove=`cat $temp_folder/remove.log | wc -l`
total_close=`cat $temp_folder/close.log | wc -l`

clear;

echo "===== Summary of the FSOP count ====="
echo ""
echo "Total lookup: $total_lookup"
echo "Total create: $total_create"
echo "Total remove: $total_remove"
echo "Total close:  $total_close"
echo ""
echo "===== Detailed report on daily basis ====="
echo ""
echo "===== Lookup ====="
cat $temp_folder/lookup.log | awk '{print $1}' | sort | uniq -c | grep -v "):"
echo "===== Create ====="
cat $temp_folder/create.log | awk '{print $1}' | sort | uniq -c | grep -v "):"
echo "===== Remove ====="
cat $temp_folder/remove.log | awk '{print $1}' | sort | uniq -c | grep -v "):"
echo "===== Close ====="
cat $temp_folder/close.log | awk '{print $1}' | sort | uniq -c | grep -v "):"

### remove the temp folder ###
echo ""
echo "Clean up the temp folder $temp_folder..."
rm -rf $temp_folder


















