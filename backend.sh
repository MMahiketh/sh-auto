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

dnf module disable nodejs -y &>> $LOG_FILE
VALIDATE $? "Disabling all nodejs modules" "Failed to diable. Exiting..."

dnf module enable nodejs:20 -y &>> $LOG_FILE
VALIDATE $? "Enabing nodejs:20 module" "Failed to enable. Exiting..."

dnf install nodejs -y &>> $LOG_FILE
VALIDATE $? "Installing nodejs:20" "Failed to install. Exiting..."

#Create expense user if not created
id expense &>> $LOG_FILE
if [ $? -ne 0 ]
then
	echo -e "expense user $R not found. $N Creating one..." | tee -a $LOG_FILE
	useradd expense
	VALIDATE $? "Creating expense user" "Failed to create user. Exiting..."
else
	echo "expense user already created." &>> $LOG_FILE
fi

mkdir -p /app
VALIDATE $? "Creating app directory" "Failed to create app dir. Exiting..."

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>> $LOG_FILE
VALIDATE $? "Downloading backend code" "Failed to download. Exiting..."

#Delete old version and deploy new version
rm -vrf /app/* &>> $LOG_FILE
cd /app; unzip /tmp/backend.zip &>> $LOG_FILE
VALIDATE $? "Unarchiving backend code" "Failed to unzip. Exiting..."

npm install &>> $LOG_FILE
VALIDATE $? "Installing node dependencies" "Failed to install. Exiting..."

cp /home/ec2-user/sh-auto/backend.service /etc/systemd/system/backend.service &>> $LOG_FILE
VALIDATE $? "Creating systemctl service for backend" "Failed to create. Exiting..."

systemctl daemon-reload &>> $LOG_FILE
VALIDATE $? "Reloading systemctl services" "Failed to reload. Exiting..."

systemctl enable backend &>> $LOG_FILE
VALIDATE $? "Enabling backend service" "Failed to enable. Exiting..."

systemctl start backend &>> $LOG_FILE
VALIDATE $? "Starting backend service" "Failed to start. Exiting..."

dnf install mysql -y &>> $LOG_FILE
VALIDATE $? "Installing mysql client" "Failed to install. Exiting..."

mysql -h srvp.mahdo.site -uroot -pExpenseApp@1 < /app/schema/backend.sql &>> $LOG_FILE
VALIDATE $? "Creating database" "Failed to create database. Exiting..."

systemctl restart backend &>> $LOG_FILE
VALIDATE $? "Restart backend service" "Failed to start. Exiting..."
