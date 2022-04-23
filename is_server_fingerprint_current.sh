#!/bin/sh -eu
# $1: internal address / host name
# env VIRTUAL_HOST required

expected_fingerprint="$(openssl x509 -fingerprint -sha256 -noout \
		-in "/etc/letsencrypt/live/$VIRTUAL_HOST/fullchain.pem")"
server_fingerprint="$(openssl s_client -connect "$1:443" \
		< /dev/null 2>/dev/null | openssl x509 -fingerprint \
		-sha256 -noout -in /dev/stdin 2> /dev/null || echo "RV=$?")"
[ "$server_fingerprint" = "$expected_fingerprint" ]
