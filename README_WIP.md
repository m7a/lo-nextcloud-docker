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
as a _backup server_ that I can share with some friends. The idea is that each
of us runs their own Nextcloud and provides access to the other friends. Then
we can send backups to friends in order to have them securely stored offsite.

Compared to a public cloud solution this gives us full control about our data
and keeps costs low especially since some of us are already running one or the
other server 24/7.

All of the users are expected to be tech-savvy enough to instruct their clients
to use TLS client certificates. In case you want to setup Nextcloud for less
tech-savvy users consider dropping client certificates because it may be a
PITA for some people to get right on their side.

Compared to other options like running an SSH server for storage, Nextcloud has
a major advantage: It can do server-side encryption. If configured correctly,
this allows administrators to remain oblivious of what content the users
upload. Thus there is no need to worry about license violations if anyone
uploads their game installer backup copy or anything.

Setup Principles
================

The setup principles in this guide are as follows:

 * Set it up with Docker
 * Use Let's Encrypt.
 * Set up TLS client certificates.
 * Automate as many maintenance tasks as possible.
 * Keep it as simple as possible under the circumstances.

## Set it up with Docker

My main argument for a setup with Docker is that I have experience with the
technology and use it for some other serivces on the same server already. Hence
it palys well in terms of regularity to attempt having _all_ of the services
in Containers. It also works pretty well for developing on one machine and
deploying to another machine later. Using `docker-compose.yml` files and scripts
it is also possible to easily reproduce the setup later if needed.

## Use Let's Encrypt

Actually I am still not sure if this is the best way to go. Let's Encrypt allows
you free TLS Server Certificates that will be accepted by all major clients by
default. It thus makes sense to use this for Nextcloud in general. It also
gives a good sense of conficence if browsers do not regularly greet you with
_This page is insecure_ etc.

In the setup presented here, an own CA is still needed for the TLS Client
Certificates, though. Also, Let's Encrypt does not actually lend itself well
to being automated (see _Installation Details_). Let's Encrypt also locks you
into certain choices like providing your services through port 443 which may
collide with other applications that you might possibly be running there
already. While Reverse Proxies solve this issue in theory, their configuration
becomes a snowflake as soon as you start mixing multiple services together in a
single configuration just to satisfy this Let's Encrypt port requirement.

If you want to deploy a setup similar to mines, do not take the complexity of
Let's Encrypt lightly and consider if running everything with your own CA might
not also be worth it?

## Set up TLS Client Certificates

Use TLS Client Certificates because they are much more secure than passwords or
any application-enforced 2FA. Its a hard layer of security that walls-off the
PHP-based Nextcloud directly on the HTTP server level.

**TLS Client Certificates are one of the three ways to do anything over
the Internet securely. The other two options are SSH and VPN btw.**

Compared to the alternatives, most clients support TLS Client Certificates
enough such that you do not need to setup any tunnel (as with SSH or VPN based
access to a website). TLS Client Certificates are thus perfectly well-suited for
the purpose.

Keep in mind that other scenarios like mobile devices, less tech-savvy users or
access through proprietary programs may require you to give up on TLS Client
Certificates. It is the strongest layer of security in the entire setup. Do not
give it up lightly.

## Automate as many Maintenance Tasks as possible

It is remarkable in a negative sense that many tutorials are based on Docker,
buit still require multiple manual steps to be performed in-sequence rather
than allowing for the idiomatic `docker-compose up`.

Also, in some tutorials, maintenance like renewing Let's Encrypt certificates
and handling upgrades comes as an afterhtought. Given that the services are
exposed to the Internet and expected to remain online for prolonged amounts
of time (we are talking about storage after all!) this seems pretty
short-sighted an approach.

This guide attempts to address some of the issues although it does not solve
them in their entirety. This is partially due to Nextcloud being a pretty
stateful application with a Database. None of this lends itself well to
fully-automatic upgrades.

As a design decision, a minimum number of Docker images is used. Also, all
modifications to the images are done by mounting files into the containers
rather than deriving custom images. This should provision for easy upgrading
even by automated scripts that just pull the images and re-create the
containers.

## Keep it as simple as possible under the Circumstances

There are some images like e.g. `nginx-proxy`
<https://github.com/nginx-proxy/nginx-proxy> that attempt to make components
like the nginx web server more docker-friendly by automating and scripting
configuration file creation. The resulting source codes are rather complex,
though, see e.g. <https://github.com/nginx-proxy/nginx-proxy/blob/main/nginx.tmpl>.

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
:   Set this to your public domain name.
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
      - NEXTCLOUD_ADMIN_USER
      - NEXTCLOUD_ADMIN_PASSWORD
      - "NEXTCLOUD_TRUSTED_DOMAINS=innerweb ${VIRTUAL_HOST}"
    depends_on:
      - postgres
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

_TODO THIS VARIABLE HAS NOT BEEN TESTED THOROUGHLY. CHECK IF IT ACTUALLY PERFORMS AS EXPECTED. ALTERNATIVELY EDIT CONFIG.PHP FILE DIRECTLY_

The `entrypoint` is overridden because while in theory, Nextcloud automatically
restarts if it cannot reach the database, in practice this yields a correupted
installation. See <https://help.nextcloud.com/t/failed-to-install-nextcloud-with-docker-compose/83681>.

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
    depends_on:
      - postgres
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
variant over HTTP is implemented here. The only path available thorugh HTTP is
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
binding port 443 for TLS, the server cannot start up without some certificate
being in place already.

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
`proxy` service. In theory this would be opational (the delay in stage 5 is long
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

TODO MISSING

Post Installation
=================

TODO CSTAT

occ app:enable encryption
occ encryption:enable
occ encryption:encrypt-all
occ encryption:disable-master-key

documentation wrt. encryption is outdated, see
https://github.com/nextcloud/server/issues/8283#issuecomment-369273503

Benchmarks
==========

Benchmark with WebDAV backend. `davs://<domain>/remote.php/dav/files/masysma/`.
Replace `<domain>` with your domain and `masysma` with your username.

The following test sets are used:

Testset   Copy Speed [MiB/s]  `du -sh`/G  `find | wc -l`
--------  ------------------  ----------  --------------
JMBB      180                 30          1737
Bupstash  18                  31          68529

The following tools are considered:

Tool          In Debian?  Version Tested  Programming Language  Links
------------  ----------  --------------  --------------------  ---------------------------------------------
davfs2        Y           1.6.0-1         C                     <https://savannah.nongnu.org/projects/davfs2>
rclone        Y           1.53.3-1+b6     Go                    <https://rclone.org/>
lftp          Y           4.8.4-2+b1      TODO TBD
webdav_sync   N           1.1.9           Java                  <http://www.re.be/webdav_sync/index.xhtml>
syncany       N           5a90af9c3f3d66  Java                  <https://www.syncany.org/>
                                                                <https://github.com/syncany/syncany>

## Setup davfs2

 * Add `clientcert /etc/davfs2/certs/client01.full.pfx` in
   `/etc/davfs2/davfs2.conf`
 * `chown root:root /etc/davfs2/certs/client01.full.pfx`
 * `mount -t davfs -o username=masysma,uid=1000,gid=1000 https://<domain>/remote.php/dav/files/masysma /media/davfs2`
 * Enter password

## Setup rclone

 * Copy client01.crt and client01.key to `/media/disk2zfs/wd`
 * `rclone config create nextcloud webdav url https://<domain>/remote.php/dav/files/masysma user masysma pass <password>`

## Setup lftp

	$ lftp
	lftp> set ssl:cert-file client01.crt
	lftp> set ssl:key-file client01.key
	lftp> set ssl:ca-file /etc/ssl/certs/ca-certificates.crt
	lftp> set ssl:verify-certificate false
	lftp> set http:use-propfind yes
	lftp> set http:use-allprop yes
	lftp> connect -u masysma,<password> https://<url>/remote.php/dav/files/masysma/
	lftp> ls

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

## No visible support for TLS client certificates

 * nextcloudcmd
 * nextcloud (GUI) failed because it could not complete authorization dance

## Benchmark davfs2

TODO WHAT IF IT WAS SO FAST BECAUSE IT IGNORED SOME UPLOAD ERRORS? IT HAS A LARGE CACHE FILE. SHOULD RE-DO THIS BENCHMARK WITH UNMOUNT AND SEE WHAT THE HECK GOES ABOUT THE CACHE FILE?

~~~
$ time rsync -a /media/disk2zfs/wd/testset_jmbb/ /media/davfs2/testset_jmbb/
real    45m34.838s
user    0m33.952s
sys     1m23.468s
~~~

## Benchmark rclone

~~~
$ time rclone --client-cert /media/disk2zfs/wd/client01.crt --client-key /media/disk2zfs/wd/client01.key sync /media/disk2zfs/wd/testset_jmbb/ nextcloud:testset_jmbb --create-empty-src-dirs
real    123m24.828s
user    1m23.665s
sys     1m27.666s
$ time rclone --buffer-size 2G --fast-list --progress --transfers 128 --client-cert /media/disk2zfs/wd/client01.crt --client-key /media/disk2zfs/wd/client01.key sync /media/disk2zfs/wd/testset_jmbb/ nextcloud:testset_jmbb --create-empty-src-dirs
~~~

## Results

Tool    JMBB [MiB/s]  Bupstash [MiB/s]
------  ------------  ----------------
davfs2  11.13         TODO TBD
rclone  4.11          TODO TBD

See Also
========


