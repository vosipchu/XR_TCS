import os
import sys
import requests
import json
from flask import Flask, request
import math

app = Flask(__name__)

TOKEN = 'TokenID'
SLACK_BASE = 'https://hooks.slack.com/services/'


@app.route('/relay', methods=['POST'])
def webhook_relay():
    if forward_request(payload=request.json):
        return "OK\n"


def forward_request(payload):
    
    url = SLACK_BASE + TOKEN
    time = str(payload['data']['series'][0]['values'][0][0])
    router = payload['data']['series'][0]['tags']['Producer']
    name = payload['data']['series'][0]['name']
    value = str(payload['data']['series'][0]['values'][0][3])
    if int(value) > 12:
        msg = '*********************\n'
        msg += 'CPU ALARM NOTIFICATION!\n\n'
        msg += 'Your router: ' + router + '\n'
        msg += 'Crossed the CPU threashold on: ' + time[:10] \
               + ' at: ' + time[11:19] + ' UTC\n'
        msg += 'the current value is: ' + value + '\n'
        msg += 'NetOps team was notified \n'
        msg += ' *********************\n\n'
    else:
        msg = '*********************\n'
        msg += 'CPU ALARM NOTIFICATION UPDATE!\n\n'
        msg += 'Your router: ' + router + '\n'
        msg += 'Is below the CPU threshold value. Crossed back on: ' \
               + time[:10] + ' at: ' + time[11:19] + ' UTC\n'
        msg += 'the current value is: ' + value + '\n'
        msg += ' All is good now \n'
        msg += ' *********************\n\n'
    slack_data = {
    "channel": "#channelname",
    "username": "uname",
    "text": msg,
    "icon_emoji": ":eyes:"
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
    app.run('localhost', port=5200)
