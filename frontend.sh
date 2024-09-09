#!/bin/bash

#/var/log/shell-auto/<file-name>-<timestamp>.log
LOG_FOLDER="/var/log/shell-auto/"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
TIMESTAMP=$(date +%Y-%m-%d::%H:%M:%S)
LOG_FILE="$LOG_FOLDER/$SCRIPT_NAME-$TIMESTAMP.log"
USERID=$(id -u)

mkdir -p $LOG_FOLDER

R="\e[31m"
G="\e[32m"
Y="\e[33m"
B="\e[34m"
N="\e[0m"

VALIDATE(){

	if [ $1 -ne 0 ]
	then
		echo -e "$2 ... $R FAILED $N" | tee -a $LOG_FILE
		
		if [ $# -eq 3 ]
		then
			echo -e "$3" | tee -a $LOG_FILE
			exit 1
		fi
	else
		echo -e "$2 ... $G SUCCESS $N" | tee -a $LOG_FILE
	fi

}

#Check for root user
VALIDATE $USERID "Root user access" "Please execute the script as root user. Exiting..."

dnf install nginx -y &>> $LOG_FILE
VALIDATE $? "Installing nnginx" "Failed to install. Exiting..."

systemctl enable nginx &>> $LOG_FILE
VALIDATE $? "Enabling nginx service" "Failed to enable. Exiting..."

systemctl start nginx &>> $LOG_FILE
VALIDATE $? "Starting nginx service" "Failed to start. Exiting..."

curl -o /tmp/frontend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-frontend-v2.zip &>> $LOG_FILE
VALIDATE $? "Downloading frontend code" "Failed to download. Exiting..."

#Delete old version and deploy new version
rm -vrf /usr/share/nginx/html/* &>> $LOG_FILE
cd /usr/share/nginx/html/; unzip /tmp/frontend.zip &>> $LOG_FILE
VALIDATE $? "Unarchiving frontend code" "Failed to unzip. Exiting..."

cp /home/ec2-user/sh-auto/expense.conf /etc/nginx/default.d/expense.conf &>> $LOG_FILE
VALIDATE $? "Creating configuration file for frontend" "Failed to create. Exiting..."

systemctl restart nginx &>> $LOG_FILE
VALIDATE $? "Restarting nginx service" "Failed to restart. Exiting..."
