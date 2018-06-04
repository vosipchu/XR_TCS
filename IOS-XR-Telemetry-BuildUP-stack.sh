#!/bin/bash

################################################################################
########             Telemetry Collection Build UP script               ########
################################################################################
## This is the script for PIKGP stack installation
## Every step will be described in details
## Feel free to modify it for your personal needs
echo -e "\e[1;46m Welcome to IOS XR MDT collection stack installation script! \e[0m";
echo -e "\e[1;46m It will generate the updates about the progress \e[0m";
echo

## This will insert environment variables you added in the text file
VARS=()
## Going through the variables to add them to a list to be used later
while read STRING; do VARS+=($STRING); done
## A very basic check for following the rules
if [ "${#VARS[*]}" != 32 ]; then
  echo -e "\e[1;31m Looks like the document with variables was filled with mistakes \e[0m"
  echo -e "\e[1;31m check and run again! \e[0m"
  exit
else
  :
fi
## Creating variables with meaningful names
PROXY=${VARS[1]}
NTP1=${VARS[3]}
NTP2=${VARS[5]}
NTP3=${VARS[7]}
MDT_DURATION=${VARS[9]}
MDT_SHARD=${VARS[11]}
TELEGRAF_DURATION=${VARS[13]}
TELEGRAF_SHARD=${VARS[15]}
SNMP_ROUTER=${VARS[17]}
SNMP_COMMUNITY=${VARS[19]}
SERVER_IP=${VARS[21]}
SLACK_TOKEN=${VARS[23]}
SLACK_CHANNEL=${VARS[25]}
SLACK_USERNAME=${VARS[27]}
GRAFANA_USER=${VARS[29]}
GRAFANA_PASSWORD=${VARS[31]}

################################################################################
########    This section adds proxy config for the current session      ########
################################################################################
if [[ ${PROXY:0:1} == "#" ]]
then
  :
else
  echo -e "\e[1;46m Adding PROXY information \e[0m";
  EXPORT=(http_proxy https_proxy ftp_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY);
  for i in "${EXPORT[@]}"; do export $i=$PROXY; done
  export no_proxy='localhost,127.0.0.1,localaddress,.localdomain.com'
  export NO_PROXY='localhost,127.0.0.1,localaddress,.localdomain.com'
fi
################################################################################


################################################################################
########       This section adds proxy config for all next logins       ########
################################################################################
if [[ ${PROXY:0:1} == "#" ]]
then
  :
else
  SERVICE=(http_proxy https_proxy ftp_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY);
  for i in "${SERVICE[@]}"; do echo $i="'$PROXY'" >> /etc/environment; done
  echo 'no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"' >> /etc/environment;
  echo 'NO_PROXY="localhost,127.0.0.1,localaddress,.localdomain.com"' >> /etc/environment;
fi
################################################################################


################################################################################
########          This section adds proxy config for apt-get            ########
################################################################################
if [[ ${PROXY:0:1} == "#" ]]
then
  :
else
  echo "Acquire::https::Proxy \"$PROXY\";" >> /etc/apt/apt.conf
  sleep 1
  echo -e "\e[1;45m PROXY information was added \e[0m";
fi
################################################################################


################################################################################
########   This section adds helper tools that will be needed later     ########
################################################################################
echo -e "\e[1;32m Installing PIP \e[0m";
apt-get -y install python-pip=8.1.1-2ubuntu0.4
echo -e "\e[1;32m Installing Requests \e[0m";
pip install requests==2.18.4
echo -e "\e[1;32m Installing Flask \e[0m";
pip install flask==1.0.2
echo -e "\e[1;32m Installing screen \e[0m";
apt-get -y install screen=4.3.1-2build1
echo -e "\e[1;32m Installing wget \e[0m";
apt-get -y install wget
echo -e "\e[1;32m Installing cURL \e[0m";
apt-get -y install curl
################################################################################

################################################################################
########   This section updates Telemetry Destination in MDT configs    ########
################################################################################
echo -e "\e[1;32m Updating Destination in the MDT Configs \e[0m";
sed -i "s/1.2.3.4/$SERVER_IP/" ~/IOSXR-Telemetry-Collection-Stack/Routers/gRPC-ASR9k.config
sed -i "s/1.2.3.4/$SERVER_IP/" ~/IOSXR-Telemetry-Collection-Stack/Routers/gRPC-NCS5500.config
sed -i "s/1.2.3.4/$SERVER_IP/" ~/IOSXR-Telemetry-Collection-Stack/Routers/TCP-ASR9k.config
sed -i "s/1.2.3.4/$SERVER_IP/" ~/IOSXR-Telemetry-Collection-Stack/Routers/TCP-NCS5500.config
################################################################################

################################################################################
########     This section configures the NTP service on your server     ########
################################################################################
echo -e "\e[1;46m Configuring NTP service \e[0m";
apt-get -y install ntp=1:4.2.8p4+dfsg-3ubuntu5.8
## Searching for default NTP servers, to comment them out
sleep 2
sed -i 's/pool \([0-3]\|ntp\)/#&/g' /etc/ntp.conf
## Now adding your servers
echo server $NTP1 iburst >> /etc/ntp.conf
echo server $NTP2 iburst >> /etc/ntp.conf
echo server $NTP3 iburst >> /etc/ntp.conf
systemctl restart ntp.service
echo -e "\e[1;45m NTP is installed, check the state later with 'ntpq -p' \e[0m"
################################################################################


################################################################################
########        This section configures InfluxDB on your server         ########
################################################################################
echo -e "\e[1;46m Configuring InfluxDB, the database for Telemetry \e[0m";
## Create a directory to store data
mkdir -p ~/analytics/influxdb && cd ~/analytics/influxdb/
## Download the package for installation
echo -e "\e[1;32m Downloading InfluxDB package \e[0m";
wget https://dl.influxdata.com/influxdb/releases/influxdb_1.5.1_amd64.deb
## Check the MD5 hash from the download
MD5_Influx=`md5sum -c <<<"5ba6c50dc917dd55ceaef4762d1f876f *influxdb_1.5.1_amd64.deb"`
## A basic notification if things went wrong
MD5_Influx_RESULT=$(echo $MD5_Influx | awk '{ print $2 }' )
if [ "$MD5_Influx_RESULT" == "OK" ];
  then
    echo -e "\e[1;32m MD5 of the file is fine, moving on \e[0m";
  else
    echo -e "\e[1;31m MD5 of the file is wrong, try to start again \e[0m";
    echo -e "\e[1;31m Exiting ... \e[0m";
		exit
fi
## Unpack and install the package after the MD5 check
echo -e "\e[1;32m Unpacking the file and making changes in the config file \e[0m";
dpkg -i influxdb_1.5.1_amd64.deb & > /dev/null
## Make changes in the InfluxDB configuration file
## Disable reporting of usage to the InfluxDB team
sleep 5
sed -i 's/# reporting-disabled = false/reporting-disabled = true/' /etc/influxdb/influxdb.conf
## Disable printing of log messages for the meta service
sed -i 's/# logging-enabled = true/logging-enabled = false/' /etc/influxdb/influxdb.conf
## Disable logging of queries before execution
sed -i 's/# query-log-enabled = true/query-log-enabled = false/' /etc/influxdb/influxdb.conf
## Disable logging of HTTP and Continues Queries
sed -i 's/# log-enabled = true/log-enabled = false/g' /etc/influxdb/influxdb.conf

## Starting InfluxDB
echo -e "\e[1;32m All is good, ready to start InfluxDB \e[0m";
influxd -config /etc/influxdb/influxdb.conf & > /dev/null
## Some time is given to finish the first steps and install the databases
sleep 2
## Check that InfluxDB is running
if pgrep -x "influxd" > /dev/null
then
    echo -e "\e[1;32m InfluxDB is running! \e[0m";
else
    echo -e "\e[1;31m There is something wrong with InfluxDB, check manually \e[0m";
		echo -e "\e[1;31m Exiting ... \e[0m";
		exit;
fi
## Install the databases (for Telemetry and SNMP data)
echo -e "\e[1;32m Adding two databases within InfluxDB for Telemetry \e[0m";
MDT_DB=`echo q=CREATE DATABASE mdt_db WITH DURATION ${MDT_DURATION}h SHARD DURATION ${MDT_SHARD}h`
TELEGRAF_DB=`echo q=CREATE DATABASE telegraf WITH DURATION ${TELEGRAF_DURATION}h SHARD DURATION ${TELEGRAF_SHARD}h`
curl -s -XPOST http://localhost:8086/query --data-urlencode "$MDT_DB" > /dev/null
curl -s -XPOST http://localhost:8086/query --data-urlencode "$TELEGRAF_DB" > /dev/null

## Check that both databases were installed
sleep 3
DB_RESULT1=$( curl -s -XPOST http://localhost:8086/query --data-urlencode "q=show databases" | egrep -o "telegraf" ) > /dev/null
DB_RESULT2=$( curl -s -XPOST http://localhost:8086/query --data-urlencode "q=show databases" | egrep -o "mdt_db" ) > /dev/null
if [ "$DB_RESULT1" == "telegraf" -a "$DB_RESULT2" == "mdt_db" ];
  then
    echo -e "\e[1;32m InfluxDB databases were added and activated! \e[0m";
    echo -e "\e[1;32m Let's move on \e[0m";
  else
          echo -e "\e[1;31m There is something wrong with InfluxDB databases, check manually \e[0m";
          echo -e "\e[1;31m Exiting ... \e[0m";
    exit;
fi
echo -e "\e[1;45m InfluxDB is fully installed, we can move on \e[0m";
################################################################################


################################################################################
########    This section configures SNMP for Telegraf on your server    ########
################################################################################
## Install SNMP and Common MIBs
echo -e "\e[1;46m SNMP and MIBs will be installed now (for Telegraf) \e[0m";
apt-get -y install snmp=5.7.3+dfsg-1ubuntu4.1
apt-get -y install snmp-mibs-downloader=1.1
## Change "snmp.conf" to accept proprietary MIBs
sed -i 's/mibs :/mibs \+ALL/' /etc/snmp/snmp.conf
download-mibs > /dev/null
## Just four Cisco MIBs are used in that example, copying them
mkdir -p  ~/.snmp/mibs && cp ~/IOSXR-Telemetry-Collection-Stack/SNMP-Telegraf/* ~/.snmp/mibs/
echo -e "\e[1;45m SNMP and MIBs are installed \e[0m";
################################################################################


################################################################################
########        This section configures Telegraf on your server         ########
################################################################################
echo -e "\e[1;46m Configuring Telegraf, the database for SNMP data \e[0m";
mkdir -p ~/analytics/telegraf && cd ~/analytics/telegraf/
echo -e "\e[1;32m Downloading the Telegraf package \e[0m";
wget https://dl.influxdata.com/telegraf/releases/telegraf_1.5.3-1_amd64.deb
## Check the MD5 hash from the download
MD5_Telegraf=`md5sum -c <<<"f3511698087f43ef270261ba45889162 *telegraf_1.5.3-1_amd64.deb"`
## A basic notification if things went wrong
MD5_Telegraf_RESULT=$(echo $MD5_Telegraf | awk '{ print $2 }' )
if [ "$MD5_Telegraf_RESULT" == "OK" ];
  then
    echo -e "\e[1;32m MD5 of the file is fine, moving on \e[0m";
  else
    echo -e "\e[1;31m MD5 of the file is wrong, try to start again \e[0m";
    echo -e "\e[1;31m Exiting ... \e[0m";
    exit
fi
## Unpack and install the package after MD5 check
echo -e "\e[1;32m Unpacking the file and making changes in the config file \e[0m";
sudo dpkg -i telegraf_1.5.3-1_amd64.deb > /dev/null
## Stopping Telegraf to work with configs
sleep 3
systemctl stop telegraf
## Disabling from running automatically after a reboot
systemctl disable telegraf.service
## Updating telegraf.conf to make sure it works as needed
## Sending all log information to /dev/null
sed -i "s/logfile = \"\"/logfile = \"\/dev\/null\"/" /etc/telegraf/telegraf.conf
## Activating SNMP, adding the IP Address of the router and the community string
sed -i "s/# \[\[inputs\.snmp\]\]/\[\[inputs\.snmp\]\]/" /etc/telegraf/telegraf.conf
sed -i "s/#   version = 2/version = 2/" /etc/telegraf/telegraf.conf
sed -i "s/#   agents = \[ \"127\.0\.0\.1\:161\" \]/agents = \[ \"$SNMP_ROUTER\" \]/" /etc/telegraf/telegraf.conf
sed -i "s/#   community = \"public\"/community = \"$SNMP_COMMUNITY\" /" /etc/telegraf/telegraf.conf
## Copying a file with several OIDs to the telegraf.conf file
cp ~/IOSXR-Telemetry-Collection-Stack/SNMP-Telegraf/SNMP-MIBS-Telegraf ~/analytics/telegraf/
sed -i '2445r SNMP-MIBS-Telegraf' /etc/telegraf/telegraf.conf
## copying MIBs to telegraf
echo -e "\e[1;32m Copying four MIBs for our profile \e[0m";
mkdir -p /etc/telegraf/.snmp/mibs && cp ~/.snmp/mibs/* /etc/telegraf/.snmp/mibs
sleep 5
echo -e "\e[1;32m All is good, ready to start Telegraf \e[0m";
sleep 2
systemctl start telegraf > /dev/null
## Check that Telegraf is running
if pgrep -x "telegraf" > /dev/null
then
		echo -e "\e[1;32m Telegraf is running! \e[0m";
else
		echo -e "\e[1;31m There is something wrong with Telegraf, check manually \e[0m";
		echo -e "\e[1;31m Exiting ... \e[0m";
		exit;
fi
echo -e "\e[1;45m Telegraf is fully installed, we can move on \e[0m";
################################################################################


################################################################################
########        This section configures Kapacitor on your server        ########
################################################################################
echo -e "\e[1;46m Configuring Kapacitor, the alerting system for InfluxDB \e[0m";
mkdir -p ~/analytics/kapacitor && cd ~/analytics/kapacitor/
wget https://dl.influxdata.com/kapacitor/releases/kapacitor_1.4.1_amd64.deb
## Check the MD5 hash from the download
MD5_Kapacitor=`md5sum -c <<<"eea9b215f241906570eafe3857e1d4c5 *kapacitor_1.4.1_amd64.deb"`
## A basic notification if things went wrong
MD5_Kapacitor_RESULT=$(echo $MD5_Kapacitor | awk '{ print $2 }' )
if [ "$MD5_Kapacitor_RESULT" == "OK" ];
  then
    echo -e "\e[1;32m MD5 of the file is fine, moving on \e[0m";
  else
    echo -e "\e[1;31m MD5 of the file is wrong, try to start again \e[0m";
    echo -e "\e[1;31m Exiting ... \e[0m";
    exit
fi
## Unpack and install the package after MD5 check
echo -e "\e[1;32m Unpacking the file and making changes in the config file \e[0m";
sudo dpkg -i kapacitor_1.4.1_amd64.deb > /dev/null
## Updating kapacitor.conf to make sure it works as needed
## (removing logging, adding InfluxDB data, etc)
sed -i "s/hostname = \"localhost\"/hostname = \"$SERVER_IP\"/" /etc/kapacitor/kapacitor.conf
sed -i "s/log\-enabled = true/log-enabled \= false/" /etc/kapacitor/kapacitor.conf
sed -i "s/file = \"\/var/#&/" /etc/kapacitor/kapacitor.conf
sed -i "s/\"INFO\"/\"OFF\"/" /etc/kapacitor/kapacitor.conf
sed -i "s/localhost\:8086/$SERVER_IP\:8086/" /etc/kapacitor/kapacitor.conf
sed -i "s/username = \"\"/username = \"admin\"/" /etc/kapacitor/kapacitor.conf
sed -i "s/password = \"\"/password = \"admin\"/" /etc/kapacitor/kapacitor.conf
sed -i '430d' /etc/kapacitor/kapacitor.conf
sed -i '430i enabled = false' /etc/kapacitor/kapacitor.conf
## Adding a TICK script for CPU alert generation
cp ~/IOSXR-Telemetry-Collection-Stack/Kapacitor/* ~/analytics/kapacitor/
sed -i "s/localhost/$SERVER_IP/" ~/analytics/kapacitor/CPU-ALERT-ROUTERS.tick
sed -i "s/localhost/$SERVER_IP/" ~/analytics/kapacitor/KAPACITOR-HELPER-CPU.py
## SED was not able to take "SlackToken" as a variable because of "/" inside the word
## A trick is used to change "/"  to "\/" to be accepted by sed
TOKEN_MODIFIED=$(awk -F'/' -v OFS="\\\/" '$1=$1' <<< $SLACK_TOKEN)
## Modifying Slack Token, channel and username
sed -i "s/TokenID/$TOKEN_MODIFIED/" ~/analytics/kapacitor/KAPACITOR-HELPER-CPU.py
sed -i "s/channelname/$SLACK_CHANNEL/" ~/analytics/kapacitor/KAPACITOR-HELPER-CPU.py
sed -i "s/uname/$SLACK_USERNAME/" ~/analytics/kapacitor/KAPACITOR-HELPER-CPU.py
## Starting Kapacitor
sudo systemctl start kapacitor >/dev/null
## Applying and activating our tick script and helper file
sleep 1
kapacitor define CPU-ALERT-ROUTERS -tick ~/analytics/kapacitor/CPU-ALERT-ROUTERS.tick
kapacitor enable CPU-ALERT-ROUTERS
python ~/analytics/kapacitor/KAPACITOR-HELPER-CPU.py & > /dev/null
sleep 2
## Check that Kapacitor is running
if pgrep -x "kapacitord" > /dev/null
then
		echo -e "\e[1;32m Kapacitor is running \e[0m";
else
		echo -e "\e[1;31m There is probably something wrong, check manually \e[0m";
		echo -e "\e[1;31m Exiting ... \e[0m";
		exit;
fi
echo -e "\e[1;45m Kapacitor is fully installed, we can move on \e[0m";
systemctl disable kapacitor.service
################################################################################


################################################################################
########        This section configures Prometheus on your server       ########
################################################################################
echo -e "\e[1;46m Configuring Prometheus, the monitoring for Pipeline \e[0m";
mkdir -p ~/analytics/prometheus && cd ~/analytics/prometheus/
wget https://github.com/prometheus/prometheus/releases/download/v1.5.2/prometheus-1.5.2.linux-amd64.tar.gz
## Check the MD5 hash from the download
MD5_Prometheus=`md5sum -c <<<"b5e34d7b3d947dfdef8758aaad6591d5 *prometheus-1.5.2.linux-amd64.tar.gz"`
## A basic notification if things went wrong
MD5_Prometheus_RESULT=$(echo $MD5_Prometheus | awk '{ print $2 }' )
if [ "$MD5_Prometheus_RESULT" == "OK" ];
  then
    echo -e "\e[1;32m MD5 of the file is fine, moving on \e[0m";
  else
    echo -e "\e[1;31m MD5 of the file is wrong, try to start again \e[0m";
    echo -e "\e[1;31m Exiting ... \e[0m";
    exit
fi
## Unpack and install the package after MD5 check
echo -e "\e[1;32m Unpacking the file and making changes in the config file \e[0m";
tar xfz prometheus-1.5.2.linux-amd64.tar.gz > /dev/null
## Add Pipeline monitoring into the configuration file
sed -i "s/localhost/$SERVER_IP/" ~/analytics/prometheus/prometheus-1.5.2.linux-amd64/prometheus.yml
echo "  - job_name: 'pipeline'" >> ~/analytics/prometheus/prometheus-1.5.2.linux-amd64/prometheus.yml
echo "    static_configs:" >> ~/analytics/prometheus/prometheus-1.5.2.linux-amd64/prometheus.yml
echo -e "      - targets: ['$SERVER_IP:8989']" >> ~/analytics/prometheus/prometheus-1.5.2.linux-amd64/prometheus.yml
## Start Prometheus
sleep 2
cd ~/analytics/prometheus/prometheus-1.5.2.linux-amd64/
sudo ./prometheus & > /dev/null
sleep 1
## Check that Prometheus is running
if pgrep -x "prometheus" > /dev/null
then
		echo -e "\e[1;32m Prometheus is running \e[0m";
else
		echo -e "\e[1;31m There is probably something wrong, check manually \e[0m";
		echo -e "\e[1;31m Exiting ... \e[0m";
		exit;
fi
echo -e "\e[1;45m Prometheus is fully installed, we can move on \e[0m";
################################################################################


################################################################################
########         This section configures Grafana on your server         ########
################################################################################
echo -e "\e[1;46m Configuring Grafana, the visualisation tool \e[0m";
mkdir -p ~/analytics/grafana && cd ~/analytics/grafana/
wget https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana_5.0.3_amd64.deb
## Check the MD5 hash from the download
MD5_Grafana=`md5sum -c <<<"f337cc57e24019e7d65892370d86f8bc *grafana_5.0.3_amd64.deb"`
## A basic notification if things went wrong
MD5_Grafana_RESULT=$(echo $MD5_Grafana | awk '{ print $2 }' )
if [ "$MD5_Grafana_RESULT" == "OK" ];
  then
    echo -e "\e[1;32m MD5 of the file is fine, moving on \e[0m";
  else
    echo -e "\e[1;31m MD5 of the file is wrong, try to start again \e[0m";
    echo -e "\e[1;31m Exiting ... \e[0m";
    exit;
fi
## Unpack and install the package after MD5 check
apt-get -y install adduser libfontconfig
echo -e "\e[1;32m Unpacking the file and making changes in the config file \e[0m";
dpkg -i grafana_5.0.3_amd64.deb > /dev/null
## Updating grafana.ini. Disable sending your info to the Grafana Team
sed -i "s/;reporting_enabled = true/reporting_enabled = false/" /etc/grafana/grafana.ini
## Create your admin-level user and password
sed -i "s/;admin_user = admin/admin_user = $GRAFANA_USER/" /etc/grafana/grafana.ini
sed -i "s/;admin_password = admin/admin_password = $GRAFANA_PASSWORD/" /etc/grafana/grafana.ini
## This will make sure your login credentials can be active for 30 days before asking to input again
sed -i "s/;login_remember_days = 7/login_remember_days = 30/" /etc/grafana/grafana.ini
## Grafana will have logging active, but the size of logs will be reduced
sed -i "s/;max_lines = 1000000/max_lines = 10000/" /etc/grafana/grafana.ini
sed -i "s/;max_days = 7/max_days = 2/" /etc/grafana/grafana.ini
echo -e "\e[1;32m Adding databases, dashboards ... \e[0m";
## Adding the databases (InfluxDB, Telegraf, Prometheus) for Grafana
cp ~/IOSXR-Telemetry-Collection-Stack/Grafana/Databases/* /etc/grafana/provisioning/datasources/
## Adding descriptions for the folders structure and locations for Grafana
cp ~/IOSXR-Telemetry-Collection-Stack/Grafana/Dashboards_Description/* /etc/grafana/provisioning/dashboards/
## Copying dashboards
mkdir /var/lib/grafana/dashboards/
cp -r ~/IOSXR-Telemetry-Collection-Stack/Grafana/Dashboards/* /var/lib/grafana/dashboards/
## Adding the correct address for Telegraf-SNMP Server
sed -i "s/\"10.30.110.42\"/\"$SNMP_ROUTER\"/" /var/lib/grafana/dashboards/snmp-telegraf/Influx-SNMP-1522021236416.json
## Installing plugins
echo -e "\e[1;32m Installing popular plugins (for future dashboards) \e[0m";
grafana-cli plugins install grafana-piechart-panel 1.1.6 > /dev/null
grafana-cli plugins install jdbranham-diagram-panel 1.4.0 > /dev/null
## Starting Grafana
sudo systemctl start grafana-server > /dev/null
sleep 2
## Check that Grafana is running
if pgrep -x "grafana-server" > /dev/null
then
		echo -e "\e[1;32m Grafana is running \e[0m";
else
		echo -e "\e[1;31m There is probably something wrong, check manually \e[0m";
		echo -e "\e[1;31m Exiting ... \e[0m";
		exit;
fi
echo -e "\e[1;45m Grafana is fully installed, we can move on \e[0m";
################################################################################


################################################################################
########         This section configures Pipeline on your server        ########
################################################################################
echo -e "\e[1;46m Configuring Pipeline, the collector tool \e[0m";
cd ~/analytics
wget https://github.com/cisco/bigmuddy-network-telemetry-pipeline/archive/master.zip

## Check the MD5 hash from the download
MD5_Pipeline=`md5sum -c <<<"1aac6ae82dbb633bdb7658b1463fd2a5 *master.zip"`
## A basic notification if things went wrong
MD5_Pipeline_RESULT=$(echo $MD5_Pipeline | awk '{ print $2 }' )
if [ "$MD5_Pipeline_RESULT" == "OK" ];
  then
    echo -e "\e[1;32m MD5 of the file is fine, moving on \e[0m";
  else
    echo -e "\e[1;31m MD5 of the file is wrong, try to start again \e[0m";
    echo -e "\e[1;31m Exiting ... \e[0m";
    exit;
fi
## Unzipping and installing Pipeline
echo -e "\e[1;32m Unpacking the file and making changes in the config file \e[0m";
unzip master.zip > /dev/null
## Renaming the directory
mv bigmuddy-network-telemetry-pipeline-master/ pipeline
## Installing the metrics.json file for all the sensor paths used in the Stack
cp ~/IOSXR-Telemetry-Collection-Stack/Pipeline/metrics.json ~/analytics/pipeline/
## Saving original pipeline.conf file
mv ~/analytics/pipeline/pipeline.conf ~/analytics/pipeline/pipeline-original-github.conf
## Copying pre-defined pipeline.conf and updating IP address
cp ~/IOSXR-Telemetry-Collection-Stack/Pipeline/pipeline.conf ~/analytics/pipeline/
sed -i "s/1.2.3.4/$SERVER_IP/" ~/analytics/pipeline/pipeline.conf
cd ~/analytics/pipeline/bin && touch dump.txt
## Stating Pipeline from a screen
echo -e "\e[1;32m Starting Pipeline (in a screen) \e[0m";
screen -dm -S Pipeline bash -c 'cd ~/analytics/pipeline; sudo ./bin/pipeline -config pipeline.conf -pem ~/.ssh/id_rsa; exec /bin/bash'
## Check that Pipeline is running
sleep 2
if pgrep -x "pipeline" > /dev/null
then
		echo -e "\e[1;32m Pipeline is running \e[0m";
else
		echo -e "\e[1;31m There is probably something wrong, check manually \e[0m";
		echo -e "\e[1;31m Exiting ... \e[0m";
		exit;
fi

## This is the end of the script!
echo -e "\e[1;45m IOS XR MDT Collection Stack is up and running. \e[0m";
echo -e "\e[1;45m Go to apply the 'wrapper.sh' script! \e[0m";
echo -e "\e[1;45m Good luck with your telemetry testing! \e[0m";

################################################################################
########                        End of the script                       ########
################################################################################
