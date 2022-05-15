---
section: 42
x-masysma-name: nextcloud_docker_tls
title: Nextcloud in Docker with Letsencrypt and TLS Client Certificates
date: 2022/04/24 15:08:29
lang: en-US
author: ["Linux-Fan, Ma_Sys.ma (Ma_Sys.ma@web.de)"]
keywords: ["nextcloud", "docker", "tls", "client", "cert", "letsencrypt"]
x-masysma-version: 1.0.0
x-masysma-website: https://masysma.lima-city.de/37/nextcloud_docker_tls.xhtml
x-masysma-repository: https://www.github.com/m7a/lo-nextcloud-docker
x-masysma-owned: 1
x-masysma-copyright: |
  Copyright (c) 2022 Ma_Sys.ma.
  For further info send an e-mail to Ma_Sys.ma@web.de.
---
Preface
=======

So you want to setup your own Nextcloud (<https://nextcloud.com/>) server?
It should be easy as well as productively useful so why not do it the modern way
with _Docker_ and _Let's Encrypt_? Surely there are countless good tutorials
about this so it should be quickly done and straight-forward. Turns out it
isn't.

In fact there are multiple good tutorials out there, none of which combine all
the things I wanted, hence I thought it might be worthwhile to document my
approach, too. I thus present the 1001st guide about how to setup Nextcloud
in Docker with Let's Encrypt here.

In case you rather want to trust some other tutorial, I found the following
resources to be helpful in creating my setup:

 * Nextcloud's official examples contain a Docker variant, see:
   <https://github.com/nextcloud/docker/tree/master/.examples/docker-compose/with-nginx-proxy/postgres/fpm>
 * Step-by-step instructions yielding a similar setup to the one presented here.
   They involve more manual steps, though. In case you want to avoid a random
   hacker's scripted approach, feel free to follow this one instead:
   <https://leangaurav.medium.com/simplest-https-setup-nginx-reverse-proxy-letsencrypt-ssl-certificate-aws-cloud-docker-4b74569b3c61>
 * This setup includes some automation but requires you to run the
   initialization script on the machine directly rather than inside a container.
   You will find that I took quite some inspiration from the tutorial.
   <https://pentacent.medium.com/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71>
   <https://raw.githubusercontent.com/wmnnd/nginx-certbot/master/init-letsencrypt.sh>.
   Please disregard the “in less than 5 minutes”. You can only do this in less
   than five minutes if you either (a) did it a lot of times already or (b)
   do not care _at all_ what is happening on your server. In case of (a) you
   wouldn't possibly be reading this page. I discurage (b), see _Abstract_
   below.
 * This page is not about Nextcloud but details out all the Let's Encrypt
   things. It is written in a straight-forward way and a useful read for
   understanding the Let's Encrypt part:
   <https://mindsers.blog/post/https-using-nginx-certbot-docker/>
 * Here is a page about how to setup nginx with TLS Client Certificates.
   Do not follow this blindly, it does some non-standard things like copying
   private RSA keys into a Docker image, not enabling TLSv1.3 and creating an
   unnecessary lot of layers. On the other hand, it provides a quick and
   straight-forward introduction:
   <https://blog.linoproject.net/tech-tip-deploy-nginx-in-container-with-client-certificate-verification/>
 * Another page about TLS client certificates that considers a slightly
   different setup but provides a neat list of `openssl` commands to copy and
   includes hints about how to setup the client certificate inside a web
   browser:
   <https://codergists.com/redhat/containers/openshift/2019/09/19/securing-http-containers-with-ssl-client-certificates-and-an-nginx-sidecar.html>

None of them seem to combine all of the nice things i.e. Nextcloud,
Let's Encrypt and TLS Client Certificates, but maybe you have different use case
where some of these are not needed anyways.

Abstract
========

This document describes how to setup a _Nextcloud_ instance on your own server.
It provides details about how to configure _Let's Encrypt_ and
_TLS Client Certificates_ such that the advantages of an automatically trusted
Let's Encrypt certificate are combined with the enhanced security of TLS Client
Certificates.

Unlike many other tutorials, this one focuses on how to spin-up the entire stack
with as much automation as possible.

Please note: While this is intended to yield a secure setup please do not
expose services to the Internet without at least _some_ understanding of what
you are doing. In this spirit, this document will not explain and assume
basic familiarity with all of the following:
Docker, Docker-Compose, TLS, Linux, Networking.

Use Case: Why Nextcloud?
========================

Nextcloud can be used for a variety of purposes. My setup focuses on using it
as a _backup storage server_ that I can share with some friends. The idea is
that each of us runs their own Nextcloud instance and provides access to the
other friends. Then we can send backups to friends in order to have them
stored offsite.

Compared to a public cloud solution this gives us full control about our data
and keeps costs low especially since some of us are already running one or the
other machine 24/7.

All of the users are expected to be tech-savvy enough to instruct their clients
to use TLS client certificates. In case you want to setup Nextcloud for less
experienced users consider dropping client certificates because they can be a
PITA for some people to set up.

Compared to other options like running an SSH server for storage, Nextcloud has
a major advantage: It can do server-side encryption. If configured correctly,
this allows administrators to remain oblivious of what content the users
upload. Thus there is no need to worry about license violations if anyone
uploads their game installer backup copy or anything.

Setup Principles
================

The setup principles in this guide are as follows:

 * Set it up with Docker.
 * Use Let's Encrypt.
 * Set up TLS client certificates.
 * Automate as many maintenance tasks as possible.
 * Keep it as simple as possible under the circumstances.

## Set it up with Docker

My main argument for a setup with Docker is that I have experience with the
technology and use it for some other serivces on the same server already. Hence
it plays well in terms of regularity to attempt having _all_ of the services
in Containers. It also works pretty well for developing on one machine and
deploying to another machine later. Using `docker-compose.yml` files and scripts
it is also possible to easily reproduce the setup later if needed.

## Use Let's Encrypt

Actually I am still not sure if this is the best way to go. Let's Encrypt allows
you to obtain free TLS Server Certificates that will be accepted by all major
clients by default. It thus makes sense to use this for Nextcloud in general. It
also gives a good sense of confidence if browsers do not regularly greet you
with _This page is insecure_.

In the setup presented here, an own CA is still needed for the TLS Client
Certificates, though. Also, Let's Encrypt does not actually lend itself well
to being automated (see _Installation Details_). Let's Encrypt locks you
into certain choices like providing your services through port 443 which may
collide with other applications that you might possibly be running there
already. While Reverse Proxies solve this issue in theory, their configuration
becomes a snowflake as soon as you start mixing multiple services together in a
single configuration just to satisfy this Let's Encrypt port requirement.

If you want to deploy a setup similar to mine's, do not take the complexity of
Let's Encrypt lightly.

## Set up TLS Client Certificates

Use TLS Client Certificates because they are much more secure than passwords or
any application-enforced 2FA. Its a hard layer of security that walls-off the
Nextcloud directly on the HTTP server level. Being webserver-based, TLS Client
Certificate protection endures even in the presence of security holes in
Nextcloud.

**TLS Client Certificates are one of the three ways to do anything over
the Internet securely. The other two options are SSH and VPN.**

Compared to the alternatives, most clients support TLS Client Certificates
enough such that you do not need to setup any tunnel (as with SSH or VPN based
access to a website). TLS Client Certificates are thus well-suited for the
purpose.

Keep in mind that other scenarios like mobile devices, less tech-savvy users or
access through proprietary programs may require you to give up on TLS Client
Certificates. Be aware that despite the complexity, it is the strongest layer of
security in the entire setup.

## Automate as many Maintenance Tasks as possible

It is remarkable in a negative sense that many tutorials are based on Docker,
but still require multiple manual steps to be performed in-sequence rather
than allowing for the idiomatic `docker-compose up`.

Also, in some tutorials, maintenance like renewing Let's Encrypt certificates
and handling upgrades comes as an afterhtought. Given that the services are
exposed to the Internet and expected to remain online for prolonged amounts
of time (we are talking about storage after all!) this seems pretty
short-sighted an approach.

This guide attempts to address some of the issues although it does not solve
them in their entirety. This is partially due to Nextcloud being a stateful
application with a database. This limits the possibilites for fully-automatic
upgrades.

As a design decision, a minimum number of Docker images is used. Also, all
modifications to the images are done by mounting files into the containers
rather than deriving custom images. This should provision for easy upgrading
even by automated scripts that just pull the images and re-create the
containers.

## Keep it as simple as possible under the Circumstances

There are images like e.g. `nginx-proxy`
<https://github.com/nginx-proxy/nginx-proxy> that attempt to make components
like the nginx web server more docker-friendly by automating and scripting
configuration file creation. The resulting source codes are rather complex,
though, e.g. <https://github.com/nginx-proxy/nginx-proxy/blob/main/nginx.tmpl>.

Some of this complexity cannot be avoided in automation, but at least for nginx
there is an easier way by creating an alsmost-static configuration file and
substituting only a limited set of environment variables. As this is already
supported by the official `nginx` container, there is no need to introduce
yet another image here.

Installation Details
====================

As promsied under _Automate as many Maintenance Tasks as possible_, the setup
presented here aims at a single `docker-compose up` to get started.

## Preconditions

The following preconditions need to be given:

Ports 80 and 443 need to be available through a public domain and forwareded to
your server. If there are firewalls, they should let these ports pass on their
way into your server.

Also, you should edit the environment file `.env`. A sample file
`_env_sample.txt` supplied as part of the repository contains the following
lines:

	POSTGRES_PASSWORD=internallyusedpasswordgibberish
	VIRTUAL_HOST=test.example.com
	LETSENCRYPT_EMAIL=letsencrypt@example.com
	NEXTCLOUD_ADMIN_USER=admin
	NEXTCLOUD_ADMIN_PASSWORD=admin

## Environment Configuration

`POSTGRES_PASSWORD`
:   Set this to a good randomly generated password. You do not normally need to
    enter it anywhere else.
`VIRTUAL_HOST`
:   Set this to your public domain name. In this article, I will use
    `test.example.com` as an example value that you need to replace with your
    own domain.
`LETSENCRYPT_EMAIL`
:   Configure an e-mail address to register with Let's Encrypt.
`NEXTCLOUD_ADMIN_USER`
:   Specify an username for the Nextcloud Administrator account.
    Use this account only to create other accounts that will then hold
    the actual data. _Do not use `admin` as the username here_. Use a name
    that reminds you that this is the admin but that is not in any of the
    common names (not root, not admin, not administrator, ...). Also, avoid
    dashes (`-`, <https://github.com/nextcloud/server/issues/13318>) in the
    username. Underscores are fine, though.
`NEXTCLOUD_ADMIN_PASSWORD`
:   Specify a password for the Nextcloud Administartor account. The usual rules
    for passwords apply.

## Quickstart with docker-compose.yml

Checkout the repository and fire it up with `docker-compose` after editing the
environment to match your setup.

~~~
git clone https://www.github.com/m7a/lo-nextcloud-docker

mv lo-nextcloud-docker nextcloud
cd nextcloud

cp _env_sample.txt .env
sensible-editor .env # edit .env as described above

docker-compose up -d # optionally leave out -d for testing purposes
~~~

## Dissecting the docker-compose.yml

While it is nice to quickly spin everything up with a single command, this does
not aid as much in understanding what all the components actually do. The
following subsections each consider individual parts of the
`docker-compose.yml` and related files. Find all the files together in
the repository.

## Database Postgresql

The beginning of the `docker-compose.yml` is as follows:

~~~{.yaml}
version: '3'

services:
  postgres:
    image: postgres:13-bullseye
    restart: unless-stopped
    volumes:
      - ./database:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
~~~

Here, a PostgreSQL database is configured with database and user name
`nextcloud`. Use image `postgres:13-bullseye` because that's a version from the
same series as also available in Debian stable. Automatic restart after
machine reboot is implemented by the `restart: unless-stopped` line. Persistent
data is stored in local directory `./database`. In case you want to manage
your data in a directory outside of the `docker-compose.yml` configuration,
feel free to reconfigure the paths accordingly.

Environment `POSTGRES_PASSWORD` is passed but not given a value. The value
configured in `.env` takes effect.

The choice of PostgreSQL over Mariadb is only a matter of preference. If you
have more/better experience with Mariadb, feel free to reconfigure the services
to use that DBMS instead.

## Redis

~~~{.yaml}
  redis:
    image: redis:6.2-bullseye
    restart: unless-stopped
    volumes:
      - ./redis:/var/lib/redis
~~~

This service is optional but improves performance significantly. Given the
generally abysmal performance of Nextcloud (see further down), it seems best to
enable this all the time!

## Nextcloud

~~~{.yaml}
  nextcloud:
    image: nextcloud:22-fpm
    restart: unless-stopped
    volumes:
      - ./storage:/var/www/html
      - ./nextcloud_entrypoint.php:/usr/local/bin/nextcloud_entrypoint.php:ro
    environment:
      - POSTGRES_PASSWORD
      - POSTGRES_DB=nextcloud
      - POSTGRES_HOST=postgres
      - POSTGRES_USER=nextcloud
      - REDIS_HOST=redis
      - NEXTCLOUD_ADMIN_USER
      - NEXTCLOUD_ADMIN_PASSWORD
      - "NEXTCLOUD_TRUSTED_DOMAINS=innerweb ${VIRTUAL_HOST}"
    depends_on:
      - postgres
      - redis
    entrypoint:
      - /usr/local/bin/php
      - "-f"
      - /usr/local/bin/nextcloud_entrypoint.php
~~~

This is the main service and hence called `nextcloud` (rather than a generic
`app` from some other tutorials). It passes environment variables to configure
Nextcloud correctly out of the box. The `NEXTCLOUD_TRUSTED_DOMAINS` is
noteworthy as it specifies a list of host names that are valid to point a
webbrowser to. For some reasons it is necessary to list the internal name
(`innerweb`) as well as the external name (provided by variable `VIRTUAL_HOST`)
here.

The `entrypoint` is overridden because while in theory, Nextcloud automatically
restarts if it cannot reach the database, in practice this yields a corrupted
installation. See
<https://help.nextcloud.com/t/failed-to-install-nextcloud-with-docker-compose/83681>.

The `nextcloud_entrypoint.php` is thus a simple wrapper that ensures that
the database is reachable before executing the Nextcloud-provided entrypoint.
It is implemented as follows:

~~~{.php}
<?php

error_reporting(E_ALL | E_NOTICE);

while(TRUE) {
	try {
		$db = new PDO("pgsql:host=postgres;port=5432;dbname=nextcloud",
				"nextcloud", getenv("POSTGRES_PASSWORD"),
				[PDO::ATTR_PERSISTENT => 0,
				PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
		$db->query("SELECT 1");
	} catch(Exception $e) {
		echo(".");
		sleep(1);
		continue;
	};
	break;
}

echo("\n");
pcntl_exec("/entrypoint.sh", ["php-fpm"]);

?>
~~~

This script just tries to connect to the `postgres` server in a loop and
execs to `/entrypoint.sh` as soon as connectivity is detected. It makes sense
to code it in PHP because that is what Nextcloud will be using in the end, too.

## Nextcloud Cron PHP

~~~{.yaml}
  cron:
    image: nextcloud:22-fpm
    restart: unless-stopped
    volumes:
      - ./storage:/var/www/html
    entrypoint: /cron.sh
    environment:
      - POSTGRES_PASSWORD
      - POSTGRES_DB=nextcloud
      - POSTGRES_HOST=postgres
      - POSTGRES_USER=nextcloud
      - REDIS_HOST=redis
    depends_on:
      - postgres
      - redis
~~~

This service is using a different entrypoint to automatically perform regularly
scheduled Nextcloud tasks. Here, I have just relied on the official example;
better implementations might be possible, but this one has the advantage that
it works without pulling another image.

## Innerweb NGINX Server

~~~{.yaml}
  innerweb:
    image: nginx:1.21
    restart: unless-stopped
    volumes:
      - ./storage:/var/www/html:ro
      - ./nginx_inner.conf:/etc/nginx/nginx.conf:ro
    environment:
      - VIRTUAL_HOST
    depends_on:
      - nextcloud
    networks:
      - proxy-tier
      - default
~~~

This is an inner nginx instance that serves the PHP as suggested by Nextcloud.
It is separated from the reverse-proxy nginx that terminates TLS as per the
official Nextcloud example `docker-compose.yml`. I am not sure if it is really
beneficial to separate them like this here, but one advantage of doing it is the
ability to specify Nextcloud-specific webserver configuration in
`nginx_inner.conf` (copied from
<https://github.com/nextcloud/docker/blob/master/.examples/docker-compose/with-nginx-proxy/postgres/fpm/web/nginx.conf>)
and TLS-specific webserver configuration in `nginx_outer.conf.template`.

## Proxy NGINX Server exposed to the Internet

~~~{.yaml}
  proxy:
    image: nginx:1.21
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
    environment:
      - VIRTUAL_HOST
    volumes:
      - ./nginx_outer.conf.template:/etc/nginx/templates/default.conf.template:ro
      - ./letsencrypt:/etc/letsencrypt:ro
      - ./is_server_fingerprint_current.sh:/usr/local/bin/is_server_fingerprint_current.sh:ro
      - ./90-await-letsencrypt.sh:/docker-entrypoint.d/90-await-letsencrypt.sh:ro
      - certbot-www:/var/www/certbot:ro
    depends_on:
      - innerweb
    networks:
      - proxy-tier
    healthcheck:
      test:
        - CMD
        - /bin/sh
        - "-euc"
        - "is_server_fingerprint_current.sh 127.0.0.1 || sleep 5; is_server_fingerprint_current.sh 127.0.0.1 || kill -s TERM 1"
      interval: 1min
      retries: 1
~~~

This is the nginx instance that will be exposed to the Internet as per the
`ports` specification. It takes a lot of special files and has a pecuilar
healthcheck to automate restarting the server in case a renewed Let's Encrypt
certificate is going to be used.

### `nginx_outer.conf.template`

~~~
server {
	listen 80;
	server_name ${VIRTUAL_HOST};

	location /.well-known/acme-challenge/ {
		root /var/www/certbot;
	}

	location / {
		return 301 https://$host$request_uri;
	}
}

server {
	listen 443 ssl;
	server_name ${VIRTUAL_HOST};
	server_tokens off;

	ssl_certificate /etc/letsencrypt/live/${VIRTUAL_HOST}/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/${VIRTUAL_HOST}/privkey.pem;

	# include /etc/letsencrypt/options-ssl-nginx.conf;
	# https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
	# -- begin options-ssl-nginx.conf --
	ssl_session_cache shared:le_nginx_SSL:10m;
	ssl_session_timeout 1440m;
	ssl_session_tickets off;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_prefer_server_ciphers off;
	ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
	# -- end options-ssl-nginx.conf --

	ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

	ssl_client_certificate /etc/letsencrypt/client-ca.crt;
	ssl_verify_client on;
	# new https://serverfault.com/questions/875229/two-way-ssl-error-400-
	ssl_verify_depth 2;

	# avoid request entity too large error
	client_max_body_size 2048M;

	location / {
		proxy_pass http://innerweb;
		proxy_set_header  X-Real-IP  $remote_addr;
	}
}
~~~

This is the production server configuration. It includes all the gory details
to use only secure ciphers, TLSv1.2 and TLSv1.3 and the client certificates.
The only Nextcloud-specific thing in here is line `client_max_body_size 2048M`
which permits large file uploads to Nextcloud.

In order for Let's Encrypt to work, it needs to recognize a challenge either in
form of a DNS record or a file served through HTTP. While the DNS record has
the advantage of not needing to expose a web server on port 80 it is also
very rarely configurable automatically with free dyndns providers. Hence the
variant over HTTP is implemented here. The only path available through HTTP is
`/.well-known/acme-challenge` whereas all other HTTP queries are redirected
to HTTPS causing the client certificate to become required.

### `is_server_fingerprint_current.sh`

This script checks the server's reported fingerprint against the on-disk
representation of the certificate. If they match, the server is already
running the most recent version of the certificate. If they do not match, the
server should be restarted as to pick up the new certificate.

Note that you do not strictly need to restart the server, a reload might be
sufficient. If have not tried that out, though.

~~~{.bash}
#!/bin/sh -eu
expected_fingerprint="$(openssl x509 -fingerprint -sha256 -noout \
		-in "/etc/letsencrypt/live/$VIRTUAL_HOST/fullchain.pem")"
server_fingerprint="$(openssl s_client -connect "$1:443" \
		< /dev/null 2>/dev/null | openssl x509 -fingerprint \
		-sha256 -noout -in /dev/stdin 2> /dev/null || echo "RV=$?")"
[ "$server_fingerprint" = "$expected_fingerprint" ]
~~~

It is not necessary to supply a valid client-side certificate for picking up
the fingerprint.

### `90-await-letsencrypt.sh`

This is another script that waits in a loop. It waits until script
`openssl_client_certificates.sh` has generated a preliminary certificate before
the nginx server can continue to start up. Without this wait, the server might
come up with some files mentioned in the configuration file being missing which
would cause the server startup to fail.

~~~{.bash}
#!/bin/sh -eu

numt=100
while { ! [ -f /etc/letsencrypt/stage ]; } || \
		[ "$(cat /etc/letsencrypt/stage)" = 1_before_first_startup ]; do
	printf .
	sleep 1
	numt=$((numt - 1))
	if [ "$numt" = 0 ]; then
		echo ERROR: Number of tries exceeded. Operation cancelled. 1>&2
		exit 1
	fi
done
~~~

## Certbot Automatic Certificate Acquisition and Renewal

As already mentioned, Let's Encrypt does not lend itself well to automation.
That is mostly because of the problem mentioned in the preceding paragraphs:
In order for Let's Encrypt to work it requires access to the challenge
through port 80. As this port is served by the same webserver that is also
binding port 443 for TLS, the server needs some certificates already to start
up.

Hence usually, this part of the setup is hand-crafted by first starting the
server with either a dummy certificate or on port 80 only. Then, the Let's
Encrypt Challenge is answered to receive the production certificates after which
the Nginx server is restarted to pick up the new certificates.

Additionally, after having performed this procedure once, a part of it has to
be re-run in order to renew certificates after a few months.

In this repository, a custom script `certbot_entrypoint.sh` is used to automate
all of these tasks. It works by passing through multiple stages some of which
are synchronized by the other parts of the automation (`90-await-letsencrypt.sh`
and `is_server_fingerprint_current.sh`).

The main part of the script `certbot_entrypoint.sh` is a large `cases` statement
that is described in the following:

~~~{.bash}
case "$stage" in
(1_before_first_startup)
	path="/etc/letsencrypt/live/$VIRTUAL_HOST"
	if [ -d "$path" ]; then
		find "$path" -mindepth 1 -delete
	else
		mkdir -p "$path"
	fi
	cp /opt/certbot/src/certbot/certbot/ssl-dhparams.pem /etc/letsencrypt
	openssl req -x509 -nodes -newkey rsa:4096 -days 10 \
			-keyout "$path/privkey.pem" -out "$path/fullchain.pem" \
			-subj "/CN=$VIRTUAL_HOST"
	uuid="$(cat /proc/sys/kernel/random/uuid)"
	echo "uuid=$uuid"
	mkdir -p /var/www/certbot/.well-known/acme-challenge
	echo "$uuid" \
		> /var/www/certbot/.well-known/acme-challenge/server_online.txt
	echo 2_await_server_online > /etc/letsencrypt/stage
	exec "$0"
	;;
~~~

The first stage is concerned with generating a self-signed certificate such that
nginx will come up despite there not being a Let's Encrypt certificate yet.
It also writes an UUID to a text file that will be served by nginx which allows
the subsequent stage to detect if the server is online yet.

~~~{.bash}
(2_await_server_online)
	uuid="$(cat \
		/var/www/certbot/.well-known/acme-challenge/server_online.txt)"
	while sleep 1; do
		printf .
		if wget -qO- http://proxy/.well-known/acme-challenge/server_online.txt 2> /dev/null | grep -qF "$uuid"; then
			break
		fi
	done
	echo
	echo 3_get_first_letsencrypt > /etc/letsencrypt/stage
	exec "$0"
	;;
~~~

This stage awaits the nginx (`proxy` service) to come online. This is a required
precondition such that Let's Encrypt can download the challenge response in the
next step.

~~~{.bash}
(3_get_first_letsencrypt)
	rm -r "/etc/letsencrypt/live/${VIRTUAL_HOST}"
	certbot certonly --webroot -w /var/www/certbot \
				--email "${LETSENCRYPT_EMAIL}" $test_cert_arg \
				-d "$VIRTUAL_HOST" --rsa-key-size 4096 \
				--agree-tos --force-renewal
	echo 4_await_server_restart > /etc/letsencrypt/stage
	exec "$0"
	;;
~~~

This stage directs `certbot` to trigger Let's Encrypt certificate generation.
As soon as it is completed, it proceeds to the next stage.

~~~{.bash}
(4_await_server_restart)
	expected_fingerprint="$(openssl x509 -fingerprint -sha256 -noout \
		-in "/etc/letsencrypt/live/$VIRTUAL_HOST/fullchain.pem")"
	while sleep 10 && ! is_server_fingerprint_current.sh proxy; do
		printf .
	done
	echo
	echo 5_update_letsencrypt_periodic > /etc/letsencrypt/stage
	exec "$0"
	;;
~~~

This stage synchronizes to the restart triggered by the healthcheck of the
`proxy` service. In theory this would be optional (the delay in stage 5 is long
enough that it should have restarted by then) but it better signals the
completion of the process to have this stage pass through.

~~~{.bash}
(5_update_letsencrypt_periodic)
	sleep 86400 || echo 5_update_letsencrypt_periodic: ignoring \
							interrupted start delay
	echo 6_update_letsencrypt_now > /etc/letsencrypt/stage
	exec "$0"
	;;
~~~

This stage passes to 6 once a day in order to have `certbot` check if it makes
sense to renew the certificate.

~~~{.bash}
(6_update_letsencrypt_now)
	echo 5_update_letsencrypt_periodic > /etc/letsencrypt/stage
	certbot renew --webroot -w /var/www/certbot --email \
		"${LETSENCRYPT_EMAIL}" $test_cert_arg \
		--rsa-key-size 4096 --agree-tos --deploy-hook \
		"echo 4_await_server_restart > /etc/letsencrypt/stage"
	exec "$0"
	;;
esac
~~~

This is the actual invocation of the certificate renewal. After this stage,
we go back to stage 5 if the process did not yield a new certificate and to
stage 4 if a new certificate was obtained (note the `--deploy-hook` argument).

Handling Updates
================

There seem to be two images widely used to address automatic upgrades of docker
containers. Both of them work by watching the base images for changes and
applying them by re-creating the container using the new image on the fly.

 1. `watchtower` <https://hub.docker.com/r/containrrr/watchtower>
 2. `ouroboros` <https://github.com/gmt2001/ouroboros/pkgs/container/ouroboros>

Both are setup very similarly. Use e.g. the following command for setting up
watchtower (copied from documentation, works):

	docker run -d --name ma-d-watchtower -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower

Doing it this way is not strictly correct given that with this setup, watchtower
could interrupt the containers at any time including during critical
transactions. Doing it correctly will only affect a small minority of cases but
require much more effort in form of suitable hook scripts. Feel free to extend
the setup into the direction and share the results :)

It makes sense to run `watchtower` outside of `docker-compose` because it is
expected that only a single instance runs _per machine_. I.e. if there are
multiple services deployed through multiple `docker-compose.yml` in different
directories then all should share the same (single) `watchtower` instance.
It would also be possible to configure `watchtower` to monitor only a limited
set of containers explicitly, but in such setups difficulty arises from ensuring
that no two services are unexpectedly handled by multiple watchtowers. Here,
the single-instance approach is preferred.

Post Installation
=================

After installation, continue configuration by the means presented by NextCloud.
To enable server-side encryption with a per-user key that cannot be recovered
by admins, the following settings seem to be needed. Run these inside the
`nextcloud` container -- not all of these features are available through the
GUI.

	occ app:enable encryption
	occ encryption:enable
	occ encryption:encrypt-all
	occ encryption:disable-master-key

Documentation wrt. encryption seems to be outdated, see
<https://github.com/nextcloud/server/issues/8283#issuecomment-369273503>

It is also required to fix some issues in `config.php` -- it remains a little
unclear which of them can be set correctly by environment variables and which
of them need to be set explicitly. In my case, the following settings had to
be added/edited:

~~~{.php}
<?php
$CONFIG = [
	'memcache.local'       => '\\OC\\Memcache\\APCu',
	'memcache.distributed' => '\\OC\\Memcache\\Redis',
	'memcache.locking'     => '\\OC\\Memcache\\Redis',
	'redis'                => ['host'=>'redis','password'=>'','port'=>6379],
	'trusted_domains'      => [0 => 'innerweb', 1 => 'test.example.com']
	'overwrite.cli.url'    => 'https://test.example.com',
	'overwritehost'        => 'test.example.com',
	'overwriteprotocol'    => 'https',
	// ...
];
?>
~~~

Benchmarks and Clients
======================

One of the big drawbacks of a solution like Nextcloud compared to other, less
web-centric variants such as exposing an SSH server for file storage or hosting
an own AWS S3 compatible storage with `minio` is the difficulty of integrating
Nextcloud as a real file store rather than only a web interface for file upload
and download.

One way is the official Nextcloud Desktop client which I will hereafter refer to
as GUI client. Additionally, multiple non-Nextcloud tools were researched and
tried for comparision. Only two of the tools could be instantiated and run
successfully in the setup at hand: `rclone` and `davfs2`. Both of them make use
of the WebDAV backend for Nextcloud which is available under
`davs://test.example.com/remote.php/dav/files/masysma/` where `test.example.com`
is your domain name and `masysma` your username.

While there is also an official Nextcloud commandline client (`nextcloudcmd`),
it does not seem to support TLS Client Certificates.

The following test data was used to check upload performance:

Testset   `du -sh`/G  `find | wc -l`
--------  ----------  --------------
JMBB      30          1737
Bupstash  31          68529

The following tools were considered:

Tool          In Debian?  Worked?  Version Tested  Programming Language  Links
------------  ----------  -------  --------------  --------------------  ---------------------------------------------
davfs2        Y           Y        1.6.0-1         C                     <https://savannah.nongnu.org/projects/davfs2>
GUI           Y           Y        3.5.0 AppImage  C++                   <https://github.com/nextcloud/desktop>
rclone        Y           Y        1.53.3-1+b6     Go                    <https://rclone.org/>
lftp          Y           N        4.8.4-2+b1      C++                   <https://github.com/lavv17/lftp>
webdav_sync   N           N        1.1.9           Java                  <http://www.re.be/webdav_sync/index.xhtml>
syncany       N           N        5a90af9c3f3d66  Java                  <https://www.syncany.org/>
                                                                         <https://github.com/syncany/syncany>

## Setup davfs2

 * Add `clientcert /etc/davfs2/certs/client01.full.pfx` in
   `/etc/davfs2/davfs2.conf`
 * `chown root:root /etc/davfs2/certs/client01.full.pfx`
 * `mount -t davfs -o username=masysma,uid=1000,gid=1000 https://<domain>/remote.php/dav/files/masysma /media/davfs2`
 * Enter password

## Setup GUI

 * Prepare `client01.full.pfx` and import it into your default web browser.
 * Start the GUI
 * Give Domain name `test.example.com`, username and password.
 * Then select that you want to use a TLS client certificate
 * Provide `client01.full.pfx` to the GUI
 * Let it open the web browser and login there, presenting the TLS certificate,
   too.
 * Then the GUI should become accessible. If not, it is most likely that any
   of the `config.php` parameters mentioned above is configured wrongly.

## Setup rclone

 * Copy client01.crt and client01.key to `/media/disk2zfs/wd`
 * `rclone config create nextcloud webdav url https://<domain>/remote.php/dav/files/masysma user masysma pass <password>`

## Benchmark davfs2

~~~
$ time rsync -a /media/disk2zfs/wd/testset_jmbb/ /media/davfs2/testset_jmbb/ && time umount /media/davfs2
real    224m23.520s
user    0m32.776s
sys     1m20.936s
/sbin/umount.davfs: waiting for mount.davfs (pid 2810) to terminate gracefully ......................................................................................................................................................................................................................................................................................................................................... OK

real    16m32.194s
user    0m2.828s
sys     0m5.319s
~~~

Benchmarks with `testset_bupstash` were cancelled for very slow and partial
progress after long times. Multiple tries were attempted and cancelled at
the following times:

 * rsync test cancelled after 4035m4.004s (IOW after about three days)
 * cp -Rv test cancelled after 1370m25.744s (IOW after about one day)

## Benchmark GUI

The GUI benchmark was performed by rsync-ing data between two VMs: One which
held the source data and one which held the directory that is being synchronized
by the GUI tool. Measurement starts when the copying is initiated and finishes
as soon as the GUI displays the green checkmark for completion. The time of this
was captured by repeatedly doing screenshots with `scrot` in intervals of 10
seconds. Due to the large data sizes and times under consideration, this should
not account for a large inaccurracy.

~~~
$ time rsync -a testset_jmbb/ linux-fan@192.168.122.200:/home/linux-fan/Nextcloud/test4/testset_jmbb/
linux-fan@192.168.122.200's password: 
date

real    2m15.060s
user    1m44.812s
sys     1m12.587s
$ date
Sat 14 May 2022 04:54:21 PM CEST
$ date # from screenshots
Sat 14 May 2022 06:42:58 PM CEST
$ maxima

(%i1) (2*60+15.060) + (06-04)*3600+(42-54)*60+58-21;
(%o1)                               6652.06
$ date; time rsync -a testset_bupstash/ linux-fan@192.168.122.200:/home/linux-fan/Nextcloud/test4/testset_bupstash/; date
Sat 14 May 2022 09:29:30 PM CEST
linux-fan@192.168.122.200's password:

real    4m54.974s
user    3m18.544s
sys     1m52.748s
Sat 14 May 2022 09:34:25 PM CEST
$ date # from screenshots
Sun 15 May 2022 02:44:33 PM CEST
~~~

In the figure, one can see two green areas: The large one on the left is the
traffic that was monitored during the upload of the JMBB test set with the
GUI client. The smaller and wider one on the right is the traffic monitored
during the upload of the Bupstash test set:

![Traffic reported on the Nextcloud machine during GUI uploads](nextcloud_docker_att/network_22_for_jmbb_gui_left)

## Benchmark rclone

~~~
$ time rclone --fast-list --progress --client-cert /media/disk2zfs/wd/client01.crt --client-key /media/disk2zfs/wd/client01.key sync /media/disk2zfs/wd/testset_jmbb/ nextcloud:testset_jmbb --create-empty-src-dirs
real    84m10.653s
user    1m18.506s
sys     1m26.575s
~~~

For the JMBB benchmark, a graphical representation of the network traffic on
the target (Nextcloud) machine can be seen in the following picture:

![JMBB rclone Traffic is on the very right](nextcloud_docker_att/nextwork_22_for_jmbb_rclone_right.png)

~~~
$ time rclone --fast-list --client-cert /media/disk2zfs/wd/client01.crt --client-key /media/disk2zfs/wd/client01.key sync /media/disk2zfs/wd/testset_bupstash/ nextcloud:testset_bupstash --create-empty-src-dirs
real    2330m55.025s
user    9m29.465s
sys     6m47.965s
~~~

## Results

Tool    JMBB [MiB/s]  Bupstash [MiB/s]
------  ------------  ----------------
davfs2  2.11          (see text)
GUI     4.67          0.51
rclone  6.03          0.22

Conclusion and Future Directions
================================

It is surprising how many bugs and missing features encouters when trying to
setup a Nextcloud securely today. Also, Nextcloud's performance on low-end
servers like the one used here is rather bad.

The recommended tool to access Nextcloud is definitely `rclone` given that it
shows the best performance. In case a synchronization running in background is
preferred, the GUI client works OK, too. `davfs2` can only be recommended for
cases where a small number of files is processed given that operations grinded
to halt with the bupstash testset.

Missing TLS Client Certificate support in official Nextcloud tools should be
fixed.  `lftp` should be made to run on Nextcloud's WebDAV.

Finally, it also seems important to not foreget about the “easier” means of
exposing a secure file storage online: SSH and Minio/S3 come into mind as
notable alternatives.

Notes from Failed Benchmarks
============================

This section collects data about programs that couldn't be convinced to run.
It serves as a list of “open ends” that could be pursued further if time
permits.

## Setup lftp

~~~
$ lftp
lftp> set ssl:cert-file client01.crt
lftp> set ssl:key-file client01.key
lftp> set ssl:ca-file /etc/ssl/certs/ca-certificates.crt
lftp> set ssl:verify-certificate false
lftp> set http:use-propfind yes
lftp> set http:use-allprop yes
lftp> connect -u masysma,<password> https://<url>/remote.php/dav/files/masysma/
lftp> ls
~~~

Displays an empty directory where the remote contents would have been expected!

## Setup Webdav_Sync

 * <https://stackoverflow.com/questions/1666052/java-https-client-certificate-authentication>
 * Couldn't get it to run. Maybe something wrong with the aliases?

## Setup Syncany

	git clone https://github.com/syncany/syncany
	cd syncany
	./gradlew installDist
	cd ./build/install/syncany/lib
	ls *.jar | tr '\n' ':'
	java -cp animal-sniffer-annotations-1.17.jar:bcpkix-jdk15on... org.syncany.Syncany

Here, it only shows `local` plugin which seems to mean it will not do WebDav?
The command series to chose (if it worked) is `init`, `connect`, `up`.
