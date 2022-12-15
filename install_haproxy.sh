#!/bin/bash

install_haproxy(){
    echo
    echo "0.1 HAPROXY - install"
    sudo apt install -y -qq haproxy 2&>1 >/dev/null
}

set_haproxy(){

echo
echo "0.2 HAPROXY - configuration"
echo "

global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000
    #socket stats
listen stats
#permet d'avoir le dashboard de haproxy sur le port 9000
    bind *:9000
    stats enable
    #cree une route
    stats uri /stats
    stats refresh 2s
    #avec une cnx
    stats auth amine:0123456
listen kubernetes-apiserver-https
#en ecoute sur le 6443 du haproxy
    bind *:6443
    mode tcp
    option log-health-checks
    timeout client 3h
    timeout server 3h
    #et derirre on derige vers le srv autokmaster
    server autokmaster autokmaster:6443 check check-ssl verify none inter 10000
    #l'algo de equilibrement de charge roundrobin
    balance roundrobin
listen kubernetes-ingress
    bind *:80
    mode tcp
    option log-health-checks"> /etc/haproxy/haproxy.cfg

for srv in $(cat /etc/hosts | grep knode | awk '{print $2}');do echo "    server "$srv" "$srv":80 check">>/etc/haproxy/haproxy.cfg
done
}

#enfin on va reloader(restart) le haproxy
reload_haproxy(){
    echo
    echo "0.3 HAPROXY - restart"
    systemctl reload haproxy
}
