#!/bin/bash

# Usage:
#
# to generate a wildcard cert
# ./cert selfsign '*.$(basename $(pwd)).$(whoami)'
#
# default to use `localhost`
# ./cert selfsign
#
# verify cert
# ./cert verify

CURRENT=$(pwd)
PROJECT=$(basename "$CURRENT")
HOST=${1:-localhost.${PROJECT}.$(whoami)}
IFS=. read HOST DOMAIN TLD <<<"${HOST##*-}"
TLD=${TLD:-$(whoami)}
DOMAIN=${DOMAIN:-${PROJECT}}

# '*.$(basename $(pwd)).inet'
FQDN=$HOST.$DOMAIN.$TLD

function selfsign {
cat > openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = $FQDN
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = $FQDN
DNS.2 = $DOMAIN.$TLD
EOF

    # rewrite '*' to 'star', for easy to read filename
    if [[ $HOST == ** ]]; then
        HOST="wildcard"
    fi

    openssl req \
            -new \
            -newkey rsa:2048 \
            -sha1 \
            -days 3650 \
            -nodes \
            -x509 \
            -keyout $(pwd)/${HOST}.key \
            -out $(pwd)/${HOST}.crt \
            -config openssl.cnf

    rm -f openssl.cnf

    echo "${HOST} key and certificate created"
    openssl x509 -in ${HOST}.crt -text -noout

    if ! [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Keychain not available, add cert to system manually"
        exit
    fi

    echo "Opening Keychain"
    open /Applications/Utilities/Keychain\ Access.app $(pwd)/${HOST}.crt
}

function verify {
    echo "start the HTTPS server first"
    openssl s_client -connect $HOST:9877
}

function dns {
    if [ ! -f /usr/local/sbin/dnsmasq ]; then
        echo "dnsmasq missing: brew install dnsmasq"
        exit
    fi

    touch /usr/local/etc/dnsmasq.conf
cat >/usr/local/etc/dnsmasq.conf<<EOF
address=/localhost.$DOMAIN/127.0.0.1
EOF

    launchctl stop homebrew.mxcl.dnsmasq | :
    launchctl start homebrew.mxcl.dnsmasq | :
}

CMDS="$@"
if [ -z "$CMDS" ]; then
    echo "missing cmds"
fi

for CMD in $CMDS; do
    case $CMD in
        selfsign)
            echo "* selfsign"
            selfsign
            ;;
        verify)
            echo "* verify cert using openssl s_client"
            verify
            ;;
        dns)
            echo "* update dns"
            dns
            ;;
        *)
            echo "* ERROR: unknown command $CMD"
            exit 1
            ;;
    esac
done
