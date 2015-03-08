# Consul cluster container for testing it

I tested [consul](https://www.consul.io/) in some docker containers on my single host.
Because of many port that consul listen, it's difficult to create the consul cluster on the docker's default network.

But, it became very easy if use [weave](http://zettio.github.io/weave/) network.

## This tested on...

Host machine

* Ubuntu 14.10
* Docker 1.5.0-dev
* Weave  0.9.0

Docker container

* ubuntu:14.04.2
* Consul 0.5.0

```bash
$ uname -a
Linux y-ubuntu 3.16.0-31-generic #41-Ubuntu SMP Tue Feb 10 15:24:04 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux

$ sudo docker version | grep -E Client\|Server
Client version: 1.5.0-dev
Client API version: 1.18
Server version: 1.5.0-dev
Server API version: 1.18

$ sudo weave version
weave script 0.9.0
weave router 0.9.0
Unable to find zettio/weavedns:0.9.0 image.
```

## Build base container

```bash
sudo docker build -t restartr/consul-ready .
```

## Install and setup weave network

```bash
wget -q -O /usr/local/bin/weave https://github.com/zettio/weave/releases/download/latest_release/weave && \
    chmod +x /usr/local/bin/weave
```

## Run containers

```bash
$ sudo weave launch
$ sudo weave start 10.0.0.1/24 weaver
$ sudo docker ps
CONTAINER ID        IMAGE                COMMAND                CREATED             STATUS              PORTS                                            NAMES
2eda921c011e        zettio/weave:0.9.0   "/home/weave/weaver    31 seconds ago      Up 30 seconds       0.0.0.0:6783->6783/tcp, 0.0.0.0:6783->6783/udp   weave
```

### consul bootstrapping

Launch `consul1` container with settings its ip to 10.0.0.1/24

```bash
$ sudo weave run 10.0.0.1/24 -it -v $(pwd -P):/opt --name=consul1 restartr/consul-ready
$ sudo docker exec consul1 ip a show ethwe
128: ethwe: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65535 qdisc pfifo_fast state UP group default qlen 1000
    link/ether a6:6e:fb:cb:7c:0f brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.1/24 scope global ethwe
       valid_lft forever preferred_lft forever
    inet6 fe80::a46e:fbff:fecb:7c0f/64 scope link
       valid_lft forever preferred_lft forever
```

And launch other containers

```bash
$ sudo weave run 10.0.0.2/24 -it -v $(pwd -P):/opt --name=consul2 restartr/consul-ready
$ sudo weave run 10.0.0.3/24 -it -v $(pwd -P):/opt --name=consul3 restartr/consul-ready
$ sudo weave run 10.0.0.4/24 -it -v $(pwd -P):/opt --name=consul4 restartr/consul-ready
```

Then, 5 containers are running.

```
$ sudo docker ps
CONTAINER ID        IMAGE                          COMMAND                CREATED             STATUS              PORTS                                            NAMES
3be672bd18b1        restartr/consul-ready:latest   "/bin/bash"            6 seconds ago       Up 5 seconds                                                         consul4
dcf304f77fdf        restartr/consul-ready:latest   "/bin/bash"            13 seconds ago      Up 12 seconds                                                        consul3
f82001d6a7b4        restartr/consul-ready:latest   "/bin/bash"            19 seconds ago      Up 17 seconds                                                        consul2
725dca3980ea        restartr/consul-ready:latest   "/bin/bash"            25 seconds ago      Up 24 seconds                                                        consul1
2eda921c011e        zettio/weave:0.9.0             "/home/weave/weaver    20 minutes ago      Up 20 minutes       0.0.0.0:6783->6783/tcp, 0.0.0.0:6783->6783/udp   weave
```

### Launch consul agent

You must specify the ip of the weave network.
If it is missed, consul bind the address of the docker's default network. And each consul process cannot connect to another process.

```
$ sudo docker exec -d consul1 /opt/consul agent -server -data-dir=/tmp/consul -bootstrap-expect 1 -bind 10.0.0.1

$ sudo docker exec consul1 ps x | grep -v ps
  PID TTY      STAT   TIME COMMAND
    1 ?        Ss+    0:00 /bin/bash
   16 ?        Sl     0:00 /opt/consul agent -server -data-dir=/tmp/consul -bootstrap-expect 1 -bind 10.0.0.1

$ sudo docker exec consul1 netstat -an --tcp | grep LISTEN
tcp        0      0 10.0.0.1:8302           0.0.0.0:*               LISTEN
tcp        0      0 127.0.0.1:8400          0.0.0.0:*               LISTEN
tcp        0      0 127.0.0.1:8500          0.0.0.0:*               LISTEN
tcp        0      0 127.0.0.1:8600          0.0.0.0:*               LISTEN
tcp        0      0 10.0.0.1:8300           0.0.0.0:*               LISTEN
tcp        0      0 10.0.0.1:8301           0.0.0.0:*               LISTEN
```

```bash
$ sudo docker exec -d consul2 consul agent -server -data-dir=/tmp/consul -config-dir=/opt/consul.d/web.json -bind 10.0.0.2
$ sudo docker exec -d consul3 consul agent -data-dir=/tmp/consul -config-dir=/opt/consul.d/web.json -bind 10.0.0.3
$ sudo docker exec -d consul4 consul agent -data-dir=/tmp/consul -config-dir=/opt/consul.d/web.json -bind 10.0.0.4
```

The cluster members is only 1 host (self).

```bash
$ sudo docker exec consul1 consul members
Node          Address        Status  Type    Build  Protocol
725dca3980ea  10.0.0.1:8301  alive   server  0.5.0  2
```


```bash
# Join consul2 to consul1
$ sudo docker exec consul2 consul join 10.0.0.1
Successfully joined cluster by contacting 1 nodes.

$ sudo docker exec consul1 consul members
Node          Address        Status  Type    Build  Protocol
725dca3980ea  10.0.0.1:8301  alive   server  0.5.0  2
f82001d6a7b4  10.0.0.2:8301  alive   server  0.5.0  2

# Join consul3 to consul1
$ sudo docker exec consul3 consul join 10.0.0.1
Successfully joined cluster by contacting 1 nodes.

# Join consul4 to consul1
$ sudo docker exec consul4 consul join 10.0.0.1
Successfully joined cluster by contacting 1 nodes.

# Show the cluster members
$ sudo docker exec consul1 consul members
Node          Address        Status  Type    Build  Protocol
725dca3980ea  10.0.0.1:8301  alive   server  0.5.0  2
f82001d6a7b4  10.0.0.2:8301  alive   server  0.5.0  2
dcf304f77fdf  10.0.0.3:8301  alive   client  0.5.0  2
3be672bd18b1  10.0.0.4:8301  alive   client  0.5.0  2
```

Then, consul4 leave from the cluster. And show the cluster members.

```bash
$ sudo docker exec consul4 consul leave
Graceful leave complete

$ sudo docker exec consul1 consul members
Node          Address        Status  Type    Build  Protocol
dcf304f77fdf  10.0.0.3:8301  alive   client  0.5.0  2
3be672bd18b1  10.0.0.4:8301  left    client  0.5.0  2       # <- The status has been changed from 'alive' to 'left'.
725dca3980ea  10.0.0.1:8301  alive   server  0.5.0  2
f82001d6a7b4  10.0.0.2:8301  alive   server  0.5.0  2
```

I will test [consul-template](https://github.com/hashicorp/consul-template) and [envconsul](https://github.com/hashicorp/envconsul) for sharing the configuration with the each cluster node.
