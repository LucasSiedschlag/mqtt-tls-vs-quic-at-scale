#!/usr/bin/env bash
# Self-signed CA and one ECDSA P-256 server certificate, shared by the TLS and QUIC listeners.
set -euo pipefail
cd "$(dirname "$0")" && mkdir -p certs && cd certs

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out ca.key
openssl req -x509 -new -key ca.key -days 365 -subj "/CN=mqtt-bench-ca" -out ca.pem

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out server.key
openssl req -new -key server.key -subj "/CN=mqtt-broker" \
  | openssl x509 -req -CA ca.pem -CAkey ca.key -CAcreateserial -days 365 \
      -extfile <(echo "subjectAltName=DNS:mqtt-broker") -out server.pem

openssl verify -CAfile ca.pem server.pem
