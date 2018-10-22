Let's continue our series of posts dealing with different basic use cases for IOS XR Model Driven Telemetry. In our previous post, we explained how you can get a big set of different [NPU stats from NCS5500](https://xrdocs.io/telemetry/tutorials/2018-09-19-ncs5500-data-plane-monitoring/).
Today we will make a short overview on how you can quickly check packet size distribution in your network on any router(s)/interface(s). As before, we will use the IOS XR MDT [collection stack](https://xrdocs.io/telemetry/tutorials/2018-06-04-ios-xr-telemetry-collection-stack-intro/) that can help you quickly build your infrastructure and start testing.

## What is it all about?

Some time ago I got a question about how telemetry can help with a quick and easy understanding of packet size distribution across the network.

Usually one can be interested in that topic for some reasons, such as to get a better understanding of the network and traffic profiles. Or to make sure there is a balanced distribution of packets of different size across routers' ports for better performance and forwarding. Or even you may want to have a fast and simple way to see if there is a potential DOS attack with the same small packet size going through your port(s).

How to get this information? The first simple way is to get the total number of bytes, the total number of packet and divide. Sounds easy, but this approach lacks the level of granularity you would probably want.

Another option is to use [Netflow](https://en.wikipedia.org/wiki/NetFlow) or [IPFIX](https://en.wikipedia.org/wiki/IP_Flow_Information_Export). But Telemetry today can't substitute Netflow. Yes, one can find MDT [YANG models for Netflow](https://github.com/YangModels/yang/tree/master/vendor/cisco/xr/632), but they will just push Netflow operational data. (Netflow is still very helpful! If you want to read more about Netflow, please, jump [here](https://xrdocs.io/cloud-scale-networking/tutorials/2018-02-19-netflow-sampling-interval-and-the-mythical-internet-packet-size/) and read nice articles from [Nicolas](https://www.linkedin.com/in/nfevrier/)!)

So, there should be some better way. The easiest one is, probably, to use what you have already, by default, and without any configuration involved.
Yes, I'm talking about interface controller stats!

Here is how it looks like when you use a CLI command:

<div class="highlighter-rouge">
<pre class="highlight">
<code>
RP/0/RP0/CPU0:NCS5501_top#sh controllers tenGigE 0/0/0/1 stats
Sun Oct 21 12:25:01.001 PDT
Statistics for interface TenGigE0/0/0/1 (cached values):

Ingress:
    Input total bytes           = 7335080089921
    Input good bytes            = 7335080089921

    Input total packets         = 10171454431
    Input 802.1Q frames         = 0
    Input pause frames          = 0
   <span style="color:blue">Input pkts 64 bytes         = 448</span>
   <span style="color:blue">Input pkts 65-127 bytes     = 340045843</span>
   <span style="color:blue">Input pkts 128-255 bytes    = 877281960</span>
   <span style="color:blue">Input pkts 256-511 bytes    = 1776379079</span>
   <span style="color:blue">Input pkts 512-1023 bytes   = 7177746466</span>
   <span style="color:blue">Input pkts 1024-1518 bytes  = 0</span>
   <span style="color:blue">Input pkts 1519-Max bytes   = 749</span>

    Input good pkts             = 10171454431
    Input unicast pkts          = 10171445103
    Input multicast pkts        = 9416
    Input broadcast pkts        = 0

    Input drop overrun          = 0
    Input drop abort            = 0
    Input drop invalid VLAN     = 0
    Input drop invalid DMAC     = 0
    Input drop invalid encap    = 0
    Input drop other            = 0

    Input error giant           = 0
    Input error runt            = 0
    Input error jabbers         = 0
    Input error fragments       = 0
    Input error CRC             = 0
    Input error collisions      = 0
    Input error symbol          = 0
    Input error other           = 0

    Input MIB giant             = 0
    Input MIB jabber            = 0
    Input MIB CRC               = 0

Egress:
    Output total bytes          = 7329708508335
    Output good bytes           = 7329708508335

    Output total packets        = 10173563487
    Output 802.1Q frames        = 0
    Output pause frames         = 0
   <span style="color:blue">Output pkts 64 bytes        = 243</span>
   <span style="color:blue">Output pkts 65-127 bytes    = 363717976</span>
   <span style="color:blue">Output pkts 128-255 bytes   = 871387990</span>
   <span style="color:blue">Output pkts 256-511 bytes   = 1751781169</span>
   <span style="color:blue">Output pkts 512-1023 bytes  = 7186675288</span>
   <span style="color:blue">Output pkts 1024-1518 bytes = 173</span>
   <span style="color:blue">Output pkts 1519-Max bytes  = 750</span>

    Output good pkts            = 10173563487
    Output unicast pkts         = 10173554134
    Output multicast pkts       = 9420
    Output broadcast pkts       = 0

    Output drop underrun        = 0
    Output drop abort           = 0
    Output drop other           = 0

    Output error other          = 0
</code>
</pre>
</div>

Basically, a router itself gives you the data you're looking for! All the details about ingress and egress packets are available there.
The only problem is that nobody wants to go to every router and collect that information from every interface and then do calculations offline. We want this to be available in real time with minimum efforts from our side.
This is right the place where Model Driven Streaming Telemetry can help!


## Gathering information about packet length distribution

The very fist thing here is to configure the correct sensor path:

```
telemetry model-driven
 sensor-group size_distribution
  sensor-path Cisco-IOS-XR-drivers-media-eth-oper:ethernet-interface/statistics/statistic
!
```

After you specified that sensor path and configured the destination group and subscription, you will have this information pushed out from the router ([check here how to quickly find out the information to be streamed!](https://xrdocs.io/telemetry/tutorials/2018-08-07-how-to-check-what-will-be-streamed/)):

<div class="highlighter-rouge">
<pre class="highlight">
<code>
{
   "node_id_str":"NCS5501_bottom",
   "subscription_id_str":"app_TEST_200000001",
   "encoding_path":"Cisco-IOS-XR-drivers-media-eth-oper:ethernet-interface/statistics/statistic",
   "collection_id":255315,
   "collection_start_time":1540157154345,
   "msg_timestamp":1540157154357,
   "data_json":[
      {
      "timestamp":1540157154353,
         "keys":[
            {
               "interface-name":"TenGigE0/0/0/30"
            }
         ],
         "content":{
            "received-total-bytes":11022910211749,
            "received-good-bytes":11022910211749,
            "received-total-frames":25575256296,
            "received8021q-frames":0,
            "received-pause-frames":0,
            "received-unknown-opcodes":0,
            <span style="color:blue"> "received-total64-octet-frames":787,</span>
            <span style="color:blue"> "received-total-octet-frames-from65-to127":2029266685,</span>
            <span style="color:blue"> "received-total-octet-frames-from128-to255":4478266535,</span>
            <span style="color:blue"> "received-total-octet-frames-from256-to511":8956564944,</span>
            <span style="color:blue"> "received-total-octet-frames-from512-to1023":10111157974,</span>
            <span style="color:blue"> "received-total-octet-frames-from1024-to1518":0,</span>
            <span style="color:blue"> "received-total-octet-frames-from1519-to-max":0,</span>
            "received-good-frames":25575256296,
            "received-unicast-frames":25575256828,
            "received-multicast-frames":0,
            "received-broadcast-frames":0,
            "number-of-buffer-overrun-packets-dropped":0,
            "number-of-aborted-packets-dropped":0,
            "numberof-invalid-vlan-id-packets-dropped":0,
            "invalid-dest-mac-drop-packets":0,
            "invalid-encap-drop-packets":0,
            "number-of-miscellaneous-packets-dropped":0,
            "dropped-giant-packets-greaterthan-mru":0,
            "dropped-ether-stats-undersize-pkts":0,
            "dropped-jabbers-packets-greaterthan-mru":0,
            "dropped-ether-stats-fragments":0,
            "dropped-packets-with-crc-align-errors":0,
            "ether-stats-collisions":0,
            "symbol-errors":0,
            "dropped-miscellaneous-error-packets":0,
            "rfc2819-ether-stats-oversized-pkts":0,
            "rfc2819-ether-stats-jabbers":0,
            "rfc2819-ether-stats-crc-align-errors":0,
            "rfc3635dot3-stats-alignment-errors":0,
            "total-bytes-transmitted":7417306553584,
            "total-good-bytes-transmitted":7417306553584,
            "total-frames-transmitted":17125047140,
            "transmitted8021q-frames":0,
            "transmitted-total-pause-frames":0,
            <span style="color:blue"> "transmitted-total64-octet-frames":788,</span>
            <span style="color:blue"> "transmitted-total-octet-frames-from65-to127":1329259298,</span>
            <span style="color:blue"> "transmitted-total-octet-frames-from128-to255":2971973230,</span>
            <span style="color:blue"> "transmitted-total-octet-frames-from256-to511":5984387559,</span>
            <span style="color:blue"> "transmitted-total-octet-frames-from512-to1023":6839426654,</span>
            <span style="color:blue"> "transmitted-total-octet-frames-from1024-to1518":0,</span>
            <span style="color:blue"> "transmitted-total-octet-frames-from1518-to-max":0,</span>
            "transmitted-good-frames":17125047140,
            "transmitted-unicast-frames":17125046643,
            "transmitted-multicast-frames":789,
            "transmitted-broadcast-frames":0,
            "buffer-underrun-packet-drops":0,
            "aborted-packet-drops":0,
            "uncounted-dropped-frames":0,
            "miscellaneous-output-errors":0
         }
      },
      ...skipped...
</code>
</pre>
</div>

It is straightforward to see that the information streamed through that sensor path contains all the needed counters and we can use that in out collector tool.  

The final step here is how to process and show this information. Having raw data is fine, but still not what we want. That's why there are two dashboards created for you! As always, feel free to mix and match dashboard panels any way you think is better for your goals.

The first dashboard gives you the flexibility to select a group of routers and a group of interfaces you're interested about. With the help of the second dashboard you can get information about a single interface, but with more details in real time.

## Group View Dashboard

The first dashboard gives you a possibility to select one or several routers and a group of interfaces you want to monitor. This is done with the help of variables in Grafana (it is worth mentioning that interfaces are tied to the selected routers, e.g. if you picked Router A and Router B, you will see only interfaces from those two devices, not from all your network).

For example, you have a location (or several locations) with peering connections, and you want to understand your traffic profile. You can select all (or a subset) of your peering routers, then choose outbound interfaces and collect a summary view of your ingress as well as egress packet size distribution. Sounds easy, right?

Packet size distribution is given in percentage on this dashboard. It was made for your convenience, as you, probably, collect the total traffic load by other means and the percentage view can give you a nice snapshot about packet length distribution.

As it was explained above, the primary goal of this dashboard is to give you a possibility to select any number of routers and interfaces.

Here is the first half of the dashboard with a "pie" panel representing the latest state of distribution of packets:

![](https://github.com/vosipchu/XR_TCS/blob/master/packet_sizes/docs/01_total_picture_pie_view.png?raw=true)


There are two "pie" panels, one showing ingress traffic distribution and another for egress traffic. Once again, it works for any number of variables (routers/interfaces) selected.

To show this summary information in Grafana, you need to use a custom query for InfluxDB.
There are several tricks integrated that give you the final number. Here is an example of query used to get the percentage value for 64-bytes packets:

```
SELECT mean("split") FROM (SELECT sum("transmitted-total64-octet-frames") / sum("transmitted-good-frames") * 100 AS "split" FROM "Cisco-IOS-XR-drivers-media-eth-oper:ethernet-interface/statistics/statistic" WHERE ("Producer" =~ /^$Router$/ AND "interface-name" =~ /^$Interface$/) AND $timeFilter) GROUP BY time(1m)
```

The final number is calculated in several steps:
- collect the total amount of packets from all routers/interfaces selected and calculate the summary
- collect the total amount of 64B packets from all routers/interfaces selected and calculate the summary
- find mean values after the division of those two numbers aggregated every 1 minute (the "group by" parameter).  

In my basic tests, I had about 12 hours of traffic information and having samples every 1 min was good enough. If you're looking for a wider time interval, you might want to change the "GROUP BY" value to something larger (you will probably have less accuracy).

Here is an example of an overview when there was a traffic change from an idle mode to a traffic generation scenario:

![](https://github.com/vosipchu/XR_TCS/blob/master/packet_sizes/docs/02_total_start_traffic.png?raw=true)

You can see the moment when the idle mode with 64-127B traffic switched to an active mode with different length packets traffic.

Okay, now let's see a more precise view from another short test:

![](https://github.com/vosipchu/XR_TCS/blob/master/packet_sizes/docs/03_total_different_sizes.png?raw=true)

Packets were generated and sent with a random lenght, and this can be seen on the bottom graph as lines are not straight anymore, dynamically showing a change of traffic profile.

That's pretty much it for the first dashboard! Let's have a look at the second one!

## Interface detailed view

This dashboard has a goal to provide a more detailed overview for some specific interface that you want to explore.

It also starts with a pie view:

![](https://github.com/vosipchu/XR_TCS/blob/master/packet_sizes/docs/04_per_port_pie_view.png?raw=true)

In addition to the percentage view, it also provides absolute values for each packet size range for your convenience.

There is no need to fully duplicate the same historical overview panel as it was on the first dashboard. But there is a potential benefit to have a possibility to see the speed of growth of some packet size range. For example, if you see that there is a fast increase in small packets ingress rate on some specific port, there might be something wrong going on, and you can start exploring deeper.

Here is an example of a situation, where traffic just started with packets of different size:

![](https://github.com/vosipchu/XR_TCS/blob/master/packet_sizes/docs/05_per_port_start_of_traffic.png?raw=true)

On the right side you can see "peaks" representing the rate of change of a specific packet size range. The height of the peak represents the amount of ingress or egress packets (higher means faster).

Here is an example of a traffic flow with packets of the same length:

![](https://github.com/vosipchu/XR_TCS/blob/master/packet_sizes/docs/06_per_port_single_packet_size.png?raw=true)

After some moment there are high peaks with a single color. It means that there is a single range dominating the bandwidth on the port. If you see something like this with, say, small packets, you might want to start some basic troubleshooting if that is not what you expect to be.

And that's it for the second dashboard!
Both dashboards and metric.json file are available for your convenience!


## Conclusion

There are several popular ways to get information about a typical packet size distribution in your network. The easiest way could be to find out the number of ingress/egress bytes, then find out the same for packets and do the division. Or you can spend some more time with Netflow and figure that information out. But what if the network itself will give you that data, and you get all the answers in just a couple of mouse clicks? Try it out. See how easily you can get information from all your peering connections or your customer facing ports.
Stay with us! More posts are coming soon!
