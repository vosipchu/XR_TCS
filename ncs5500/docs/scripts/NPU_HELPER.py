#------------------------------------------------------------------------------
#
#    Copyright (C) 2018 Cisco Systems, Inc.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#------------------------------------------------------------------------------

import requests, json, threading
from flask import Flask, request
from influxdb import InfluxDBClient
from netmiko import ConnectHandler

## list of devices in the lab
DEVICES = {
    'NCS5501_top':      '10.30.110.41',
    'NCS5501_bottom':   '10.30.110.42',
    'NCS5502_bottom':   '10.30.110.43',
    'NCS5502_top':      '10.30.110.44',
    'ASR9006':          '10.30.110.45',
    'NCS5502_center':   '10.30.110.46',
}

## logins for devices
USERNAMES = {
    'NCS5501_top':      'cisco',
    'NCS5501_bottom':   'cisco',
    'NCS5502_bottom':   'cisco',
    'NCS5502_top':      'cisco',
    'ASR9006':          'cisco',
    'NCS5502_center':   'cisco',
}

## paswords for devices
PASSWORDS = {
    'NCS5501_top':      'cisco',
    'NCS5501_bottom':   'cisco',
    'NCS5502_bottom':   'cisco',
    'NCS5502_top':      'cisco',
    'ASR9006':          'cisco',
    'NCS5502_center':   'cisco',
}

## information to access Influx database
DB_ADDRESS = '10.30.110.60'
DB_PORT = '8086'
INFLUXDB_USER = 'admin'
INFLUXDB_PASSWORD = 'admin'
INFLUXDB_NAME = 'mdt_db'
DB_USER = ''
DB_PASSWORD = ''

## finding LLDP neighbors of the router under stress
LLDP_NEIGHBORS = '''
SHOW TAG VALUES FROM \
"Cisco-IOS-XR-ethernet-lldp-oper:lldp/nodes/node/neighbors/summaries/summary" \
WITH KEY="device-id" \
WHERE "Producer" = '{}'
'''

## finding ports on neighbors to increase ISIS metrics
LLDP_PORTS = '''
SELECT "lldp-neighbor__receiving-parent-interface-name" \
FROM "Cisco-IOS-XR-ethernet-lldp-oper:lldp/nodes/node/neighbors/summaries/summary" \
WHERE ("Producer" = '{}' AND "device-id" = '{}') \
AND time > now() - 5s
'''

## an alert message after crossing the threshold (up) 
MESSAGE_1= '''
*******************************
NPU ALARM NOTIFICATION !
*******************************

Your router: {} 
Crossed the NPU threashold on: {} at: {} UTC
The current value is: {}

NetOps team was notified
The router is off the traffic flow
'''

## an alert message after crossing the threshold (down) 
MESSAGE_2= '''
********************************
NPU ALARM WAS REMOVED !
********************************

Your router: {} 
Is below the NPU threshold value. on: {} at: {} UTC
The current value is: {}
All is good now !
'''


def isis (dut):

    ## an empty list to be used to store mid point results
    ROUTERS, PORTS = [], {}

    ## connection to the influxdb database
    connection = InfluxDBClient(
        DB_ADDRESS, 
        DB_PORT, 
        INFLUXDB_USER, 
        INFLUXDB_PASSWORD, 
        INFLUXDB_NAME
    )
    
    ## collecting all lldp neighbors
    lldp_routers = connection.query(LLDP_NEIGHBORS.format(dut)).items()

    for router in lldp_routers[0][1]:
        ROUTERS.append(router['value'])

    ## finding corresponding ports on neighbors
    for router in ROUTERS:
        try:
            lldp_ports = connection.query(LLDP_PORTS.format(router, dut)).items()
            for port in lldp_ports[0][1]:
                PORTS[router] = (port['lldp-neighbor__receiving-parent-interface-name'])
        except:
            pass
    
    ## function for threading
    def worker(k, v):
        router_connect = ConnectHandler(
            device_type='cisco_xr', 
            ip=DEVICES[k], 
            username=USERNAMES[k], 
            password=PASSWORDS[k]
        )

        isis_change = router_connect.send_config_set([
        	'router isis 1',
        	'interface {}'.format(v),
        	'address-family ipv4 unicast',
        	'metric 1000000 level 2',
        	'address-family ipv6 unicast',
        	'metric 1000000 level 2',
        	'commit'
            ])
    
    ## activating threading
    threads = []
    for k,v in PORTS.items():
        t = threading.Thread(target=worker, args=(k,v))
        threads.append(t)
        t.start()

## main part for catching updates from Kapacitor
app = Flask(__name__)

TOKEN = 'T4GNJG4BV/B8WBWCM45/gwpFByQ1U14CnidljFwxqmIp'
SLACK_BASE = 'https://hooks.slack.com/services/'


@app.route('/relay', methods=['POST'])
def webhook_relay():
    if forward_request(payload=request.json):
        return "OK\n"

## formatting the message and initiating ISIS metrics increases
def forward_request(payload):

    url = SLACK_BASE + TOKEN
    time = str(payload['data']['series'][0]['values'][0][0])
    dut = payload['data']['series'][0]['tags']['Producer']
    value = str(payload['data']['series'][0]['values'][0][1])
    if int(value) > 650000:
        msg = MESSAGE_1.format(dut, time[:10], time[11:19], value)
        isis (dut)

    else:
        msg = MESSAGE_2.format(dut, time[:10], time[11:19], value)
    
    ## details for Slack
    slack_data = {
    "channel": "#04_npu_updates",
    "username": "Telemetry_Bot",
    "text": msg,
    "icon_emoji": ":zap:"
    }
    debug = ''
    response = requests.post(url+ debug, data=json.dumps(slack_data),
                             headers={'Content-Type': 'application/json'})
    if response.status_code != 200:
        raise ValueError(
            'Request to slack returned an error %s, the response is:\n%s'
            % (response.status_code, response.text)
        )
    else:
        return True

if __name__ == '__main__':
    app.run('10.30.110.40', port=5300)