#!/bin/bash
Server=$1
User=$2
Password=$3
CMD=$4

expect -c "
    
    set timeout 30
    spawn ssh $User\@$Server $CMD
    expect {
        'Password:' { 
            send \"$Password\n\"
        }
        \"Are you sure you want to continue connecting (yes/no)?\" {
            send \"yes\r\"
            exp_continue
        }
    }
"
