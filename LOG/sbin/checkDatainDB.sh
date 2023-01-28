#!/bin/bash
TD=$(date +"%d-%m-%Y")
rm list
touch list
DATABASE_LIST=$(mysql -u root -pabc-1234 -e 'show databases;')
for item in ${DATABASE_LIST[@]};
do
if [[ ( $item != "Database" && $item != "information_schema" && $item != "Syslog" && $item != "sys" && $item != "syslog" && $item != "mysql" && $item != "performance_schema" && $item != "log" && $item != "ServerContext3" && $item != "test") ]]; then
echo $item >> list
mapfile -t DB < list
fi
done

for i in "${!DB[@]}"; do
fck () { mysql -u root -pabc-1234 -D ${DB[$i]} -e 'SELECT * FROM `'$TD'-SystemEvents` where DeviceReportedTime > now() - interval 5 minute LIMIT 0,1;' | grep -o DeviceReportedTime ; }
if fck == "DeviceReportedTime" ;
then
mysql -u root -pabc-1234 -e "update ServerContext3.ServerModels set connectivitystatus='True' where dbidentity='${DB[$i]}'";
else
mysql -u root -pabc-1234 -e "update ServerContext3.ServerModels set connectivitystatus='False' where dbidentity='${DB[$i]}'";
fi
done

rm list
