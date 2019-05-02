#!/bin/bash

DATE_NOW=`date +%F`
FOLDER="/home/matt/work_tools_fs"
cd $FOLDER

git add *
git commit -m "Updated at $DATE_NOW"
git push -u origin master
