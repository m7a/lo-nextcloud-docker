#!/bin/sh -e
# Ma_Sys.ma Certbot Entrypoint 1.0.0, Copyright (c) 2022 Ma_Sys.ma.
# For further info send an e-mail to Ma_Sys.ma@web.de.
#
# ## SYNOPSIS
#
# certbot_entrypoint.sh - Automate certificate issuing and renewal in Container
#
# ## ENVIRONMENT VARIABLES
#
# VIRTUAL_HOST
# 	Your domain name
# LETSENCRYPT_EMAIL
# 	Your E-Mail
#
# ## FILES
#
#  - /etc/letsencrypt
#  - /var/www/certbot
#  - /tmp/debug_sleep

if [ -f /tmp/debug_sleep ]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S') | $$] stage=0_debug_sleep"
	while [ -f /tmp/debug_sleep ] && sleep 10; do
		printf .
	done
	echo
fi

if [ -z "$VIRTUAL_HOST" ] || [ -z "$LETSENCRYPT_EMAIL" ]; then
	echo "ERROR: Missing required environment variables" \
		"VIRTUAL_HOST=$VIRTUAL_HOST," \
		"LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL!"
	exit 1
fi

set -u

# set this to empty (test_cert_arg=) for production and to "--test-cert" for dbg
test_cert_arg=

if [ -f /etc/letsencrypt/stage ]; then
	stage="$(cat /etc/letsencrypt/stage)"
else
	stage=1_before_first_startup
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S') | $$] stage=$stage"

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
(3_get_first_letsencrypt)
	# Need to delete to avoid "live directory exists for ${VIRTUAL_HOST}"
	# error.
	rm -r "/etc/letsencrypt/live/${VIRTUAL_HOST}"
	certbot certonly --webroot -w /var/www/certbot \
				--email "${LETSENCRYPT_EMAIL}" $test_cert_arg \
				-d "$VIRTUAL_HOST" --rsa-key-size 4096 \
				--agree-tos --force-renewal
	echo 4_await_server_restart > /etc/letsencrypt/stage
	exec "$0"
	;;
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
(5_update_letsencrypt_periodic)
	sleep 86400 || echo 5_update_letsencrypt_periodic: ignoring \
							interrupted start delay
	echo 6_update_letsencrypt_now > /etc/letsencrypt/stage
	exec "$0"
	;;
(6_update_letsencrypt_now)
	echo 5_update_letsencrypt_periodic > /etc/letsencrypt/stage
	certbot renew --webroot -w /var/www/certbot --email \
		"${LETSENCRYPT_EMAIL}" $test_cert_arg \
		--rsa-key-size 4096 --agree-tos --deploy-hook \
		"echo 4_await_server_restart > /etc/letsencrypt/stage"
	exec "$0"
	;;
esac
