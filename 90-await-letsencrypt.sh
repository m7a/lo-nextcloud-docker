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
