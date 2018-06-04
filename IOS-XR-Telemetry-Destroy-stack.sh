#!/bin/bash
#######################################################
######### Telemetry Collection Destroy script #########
#######################################################

#######################################################
######## This removes InfluxDB from your server #######
#######################################################
echo -e "\e[1;46m Removing InfluxDB \e[0m";
PID=`pgrep influxd`
kill -9 $PID
dpkg --purge influxdb
rm -r ~/analytics/influxdb
rm -r /var/lib/influxdb
echo -e "\e[1;45m Done! \e[0m";
#######################################################


#######################################################
####### This removes Telegraf from your server ########
#######################################################
echo -e "\e[1;46m Removing Telegraf \e[0m";
PID=`pgrep telegraf`
kill -9 $PID
dpkg --purge telegraf
rm -r ~/analytics/telegraf
rm -r /etc/telegraf/
echo -e "\e[1;45m Done! \e[0m";
#######################################################


#######################################################
####### This removes Kapacitor from your server #######
#######################################################
echo -e "\e[1;46m Removing Kapacitor \e[0m";
dpkg --purge kapacitor
PID=`pgrep kapacitor`
kill -9 $PID
rm -r ~/analytics/kapacitor
rm -r /var/lib/kapacitor
rm -r /var/log/kapacitor
PID=`ps -ef | grep KAPACITOR-HELPER-CPU | \
grep -v "grep" | awk '{print $2}'`
kill -9 $PID
echo -e "\e[1;45m Done! \e[0m";
#######################################################


#######################################################
###### This removes Prometheus from your server #######
#######################################################
echo -e "\e[1;46m Removing Prometheus \e[0m";
PID=`pgrep prometheus`
kill -9 $PID
rm -r ~/analytics/prometheus
echo -e "\e[1;45m Done! \e[0m";
#######################################################


#######################################################
######## This removes Grafana from your server ########
#######################################################
echo -e "\e[1;46m Removing Grafana \e[0m";
PID=`pgrep grafana`
kill -9 $PID
dpkg --purge grafana
rm -r ~/analytics/grafana
rm -r /etc/grafana
rm -r /var/lib/grafana
echo -e "\e[1;45m Done! \e[0m";
#######################################################


#######################################################
######## This removes Pipeline from your server #######
#######################################################
echo -e "\e[1;46m Removing Pipeline \e[0m";
PID=`pgrep pipeline`
kill -9 $PID
pkill screen 2>/dev/null
rm -r ~/analytics/pipeline
rm ~/analytics/master.zip
rm -r ~/analytics
echo -e "\e[1;45m Every component was removed! \e[0m";

#######################################################
########         End of the script              #######
#######################################################
