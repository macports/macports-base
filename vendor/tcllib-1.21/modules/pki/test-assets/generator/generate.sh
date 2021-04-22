#!/bin/bash

# Generates a self-signed certificate and a client certificate with max 
# options for testing purposes.

set -e

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

NAME=pkitest

# Note: since the script is used for experimenting, I do not directly replace files
# in the test-assets directory.

# First the CA
openssl genpkey -outform PEM -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ${NAME}-ca-private.key
openssl req -x509 -nodes -days 3650 -key ${NAME}-ca-private.key -config ${NAME}-ca.conf -extensions req_ext -nameopt utf8 -utf8 -out ${NAME}-ca.crt

# Now the intermediate CA
openssl genpkey -outform PEM -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ${NAME}-ca2-private.key
openssl req -new -nodes -key ${NAME}-ca2-private.key -config ${NAME}-ca2.conf -nameopt utf8 -utf8 -out ${NAME}-ca2.csr -extensions req_ext
openssl x509 -req -in ${NAME}-ca2.csr -days 1825 -CAkey ${NAME}-ca-private.key -CA ${NAME}-ca.crt -extensions cert_ext -extfile ${NAME}-ca2.conf -out ${NAME}-ca2.crt -CAcreateserial

# Create a certificate with all certificate options we know
openssl genpkey -outform PEM -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ${NAME}-private.key
openssl req -new -nodes -key ${NAME}-private.key -config ${NAME}.conf -nameopt utf8 -utf8 -out ${NAME}.csr -extensions req_ext
openssl x509 -req -in ${NAME}.csr -days 1825 -CAkey ${NAME}-ca-private.key -CA ${NAME}-ca.crt -extensions cert_ext -extfile ${NAME}.conf -out ${NAME}.crt -CAcreateserial

# Clean up serial file - a new one will be created each time
rm -f ${NAME}-ca.srl

echo ----------------
echo Certificates generated. To copy certificates etc. into test directory, execute:
set -f
echo mv -f ${NAME}*.crt ${NAME}*.key ${NAME}*.csr $(dirname "$SCRIPTPATH")
