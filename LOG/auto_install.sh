#!/bin/bash

#Bash Arguments

#if [ $# -eq 1 ]
#then
#  echo "Usage: sudo ./home/$USER/auto_install.sh $USER"
#  exit 1
#fi

echo "**** Configuring LogServer ****"

LUSER=$(getent group sudo | cut -d: -f4)

#Update apt repo

apt-get -qqy update


#Bash Functions

function AddApacheConf()
{

cat >/etc/apache2/conf-enabled/logserver.conf <<EOL
<VirtualHost *:80>

ProxyPreserveHost On

ProxyPass / http://127.0.0.1:5000/

ProxyPassReverse / http://127.0.0.1:5000/

ErrorLog /var/log/apache2/aspnetcoredemo-error.log

CustomLog /var/log/apache2/aspnetcodedemo-access.log common

</VirtualHost>
EOL

}



function AddLogserverService()
{

cat >/etc/systemd/system/logserver.service <<EOL
[Unit]

Description=Logserver Service

[Service]

WorkingDirectory=/home/$LUSER/publish/

ExecStart=/home/$LUSER/publish/LogServer.Presentation.WebMVC --urls "http://*:5000;"

Restart=always

RestartSec=10

SyslogIdentifier=Logserver

User=$LUSER

Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]

WantedBy=multi-user.target

EOL

}



# Install MySQL without password prompt
# Set root password to 'abc-1234'

debconf-set-selections <<< "mysql-server mysql-server/root_password password abc-1234"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password abc-1234"

# Install MySQL Server
echo "**** Installing MySQL Version 5.7 ****"
apt-get -qqy install mysql-server-5.7
#Configure for outside access
sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
mysql -uroot -pabc-1234 -e "GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY 'abc-1234' WITH GRANT OPTION;"
mysql -uroot -pabc-1234 -e "FLUSH PRIVILEGES;"
chown -R mysql:mysql /mnt/data/
echo "**** Restarting MySQL ****"
systemctl restart mysql

#Install Rsyslog-Mysql

echo "**** Installing RSyslog ****"
debconf-set-selections <<< "rsyslog-mysql	rsyslog-mysql/mysql/app-pass password abc-1234"
debconf-set-selections <<< "rsyslog-mysql	rsyslog-mysql/app-password-confirm password abc-1234"
apt-get -qqy install rsyslog rsyslog-mysql


#Copy Config Files

echo "**** Copying Config File ****"
rm -f /etc/rsyslog.conf
cp ./rsyslog.conf /etc/rsyslog.conf
chmod -R 777 /home/$LUSER/publish/
rm /etc/rsyslog.d/mysql.conf
cp /home/$LUSER/logcnf.conf /etc/rsyslog.d/logcnf.conf
cp /home/$LUSER/portcnf.conf /etc/rsyslog.d/portcnf.conf
chmod -R 777 /etc/rsyslog.d/
chmod 777 /etc/rsyslog.conf


#Apache2 Config

echo "**** Installing Apache2 ****"
apt-get -qy install apache2
a2enmod proxy proxy_http proxy_html
echo "**** Copying Apache2 Config ****"
AddApacheConf
echo "**** Restarting Apache ****"
systemctl restart apache2

#Log Server Service Function

echo "**** Adding Logserver Service ****"
AddLogserverService

echo "**** Enabling Logserver Service ****"
systemctl enable logserver


echo "**** Starting Logserver Service ****"
#systemctl start logserver


#PERMISSIONS
chmod +x /home/$LUSER/sbin/checkDatainDB.sh

#Add Crontab Entry

echo "**** Adding Crontab Entry  ****"
rm tempcron
echo "0 5 * * * sudo systemctl restart rsyslog" >> tempcron
echo "30 * * * * bash /home/$LUSER/sbin/checkDatainDB.sh" >> tempcron
echo "0 * * * * bash /home/$LUSER/sbin/checkDatainDB.sh" >> tempcron
crontab tempcron
rm tempcron


#Adding Sudoers
echo "Adding Sudoers Entry"

echo "$LUSER ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers

echo "Installation Done"



#Self Delete

rm -f auto_install.sh
