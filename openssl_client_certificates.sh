#!/bin/sh -exu

# from https://gist.githubusercontent.com/welshstew/536e6b77f40e890c01a52b9172e84c11/raw/55c95f7d3ad6b7272096fa3995e2b42e59c1e132/generate-certificates.sh

. .env # source VIRTUAL_HOST variable into script

# Generate CA certificate
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 8000 -sha256 -subj "/C=DE/ST=Hesse/L=/O=/OU=/CN=$VIRTUAL_HOST" -key ca.key -out ca.crt

for clnt in 01 02 03 04 05; do
	# Create the Client Key and CSR
	openssl genrsa -out client$clnt.key 4096
	openssl req -new -key client$clnt.key -subj "/C=DE/ST=Hesse/L=/O=/OU=/CN=$VIRTUAL_HOST" -sha256 -out client$clnt.csr

	# Sign the client certificate with CA cert.
	openssl x509 -req -days 4000 -in client$clnt.csr -CA ca.crt -CAkey ca.key -set_serial $clnt -out client$clnt.crt
	# Bundle the private key & cert for end-user client use
	cat client$clnt.key client$clnt.crt ca.crt > client$clnt.full.pem
	# Bundle client key into a PFX file - this is what will be imported to the browser to use as a client certifcate
	openssl pkcs12 -export -nodes -out client$clnt.full.pfx -inkey client$clnt.key -in client$clnt.full.pem -certfile ca.crt
done
