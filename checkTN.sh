#! /bin/bash

# Name: checkTN
# Version 0.4

# Check the Technology systems and send a text message if system is not
# functioning correctly
# Files:
#    checkTN.config - Configuration file. This is where you set up the files
#                     This file should reside in the same directory as the script 

function mailSend() {

# Function to send mail. Has 3 parameters
#     mailFiles - The file containing the message to email
#     emailAcct - The email account and password for the SMTPS server
#     Users - The list of users to send the message to

LogStep "Entering Send Mail"

mailFile="$1"
emailAcct="$2"
Users="$3"
OLDIFS=$IFS
IFS=!
for mailid in $Users
do
    LogStep $mailid
    curl --url 'smtps://smtp.gmail.com:465' --ssl-reqd \
      --mail-from $From --mail-rcpt $mailid \
      --upload-file $mailFile --user $emailAcct
    LogStep "Sent mail to: $mailid"
done
IFS=$OLDIFS
}
function LogStep() {

# Function for logging which includes date and time stamp

if [ -e $Logfile ];
then
    touch $Logfile
fi
if [ $# -eq 1 ];
then
    echo "[ $(date) ] $1" >> $Logfile
else
    echo "Argument Error with Logging"
fi
}

# Load the configuration file

. checkTN.config

#Email to SMS gateways
#
#T-Mobile:(SMS & MMS) 
#number@tmomail.net (SMS & MMS) 
#Google Fi (Project Fi):(SMS & MMS) 
#number@msg.fi.google.com (SMS & MMS) 

# Create a temp file and add a header file location in config file

touch $checkTMP
echo "Technology Nursery has an issue!! " > $checkTMP
echo "-------------------- " >> $checkTMP
echo " " >> $checkTMP

# Status will be set to 1 if any service is down

Status=0

# Test if doing debug
# The Apps variable could be put in the configuration file I opted against it.

if [ $# -ge 1 ];
then
    Apps='jira.web jira.nejug jira jira.mobile confluence confluence.cfg https://store https://tssg foo'
else
    Apps='jira.web jira.nejug jira jira.mobile confluence confluence.cfg https://store https://tssg'
fi

# check each service

for svc in $Apps
do 
    LogStep "Testing: $svc"
    SiteStatus=$(curl -s ${svc}.technologynursery.org/status | sed -e "s/^.*RUNNING.*$/up/" -e "s/Passed.*/up/" ) ; 
    LogStep "$SiteStatus"
    if [[ $SiteStatus != "up" ]];
    then 
        echo $svc 'Is Down' >> $checkTMP
        LogStep "$svc $SiteStatus"
        Status=1
    fi
done

# There is an issue Technology Nursery
# You want to only send this notification once during a failure

LogStep "Status =  $Status"
if [ $Status -eq 1 ];
then
    if [  -e ~/checkTN.notify ];
    then
        LogStep "Skipping Notification System already reported as having an issue"
    else
        mailSend $checkTMP $Acct $Users
        LogStep "Sending mail to users"

# We create a file with the date and time.  This will be used to 
# stop sending notifications until the system are back up

        echo "Notified " date > $Notify
	LogStep "Sent Notification"
        sleep 10

    fi                                    #close out inner if statement
fi                                        #close out outer if statment

# Technology Nursery is back online fully
# Checking the Status as being all up and after a failure you
# need to remove the checkTN.notify file.

if [ $Status -eq 0  -a -e  $Notify ];
then
    echo "Technology Nursery is back up !!" > $checkTMP
    mailSend $checkTMP $Acct $Users
    LogStep "Notified users that services are back up"
    sleep 10
    rm $Notify
fi
rm $checkTMP
echo "All done" 

