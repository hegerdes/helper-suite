#!/bin/bash

set -e

#Make it pritty
RED='\033[0;31m'
NC='\033[0m'
GRN='\033[0;32m'

#easy config
CA_FILE_NAME="ca"
KEY_SIZE=2048
DST_DIR="certificates"
CA_VALID_DAYS="3650"
CLIENT_VALID_DAYS="365"
CERT_FILE_EXTENTION="pem"
DHPARAM_FILE="${DST_DIR}/dhparam.${CERT_FILE_EXTENTION}"
PFX_EXPORT_PW="my-ca"
FORCE_CA_OVERRIDE="no"

# Add aditional names for mor clients (seperated by space)
CLIENTS=(localhost client1 client2 client3)

# Cert data
CA_CN="hegerdes"
CA_COUNTRY="DE"
CA_STATE="Hamburg"
CA_CITY="Hamburg"
CA_ORG="hegerdes"
CA_ORG_UNIT="HEAD"
CA_MAIL="hegerdes@outlook.de"

# Cert data
COUNTRY="${CA_COUNTRY}"
STATE="${CA_STATE}"
CITY="${CA_CITY}"
ORG="${CA_ORG}"
ORG_UNIT="${CA_ORG_UNIT}"
# MAIL="${CA_MAIL}" - will be ${client}@${ORG}.${COUNTRY,,}"
# CN="${CA_CN}" - will be the entry in $CLIENTS

#Set CWD
cd "$(dirname "$0")"
#Create DST-folder
mkdir -p "$DST_DIR"

#Check openssl command
if ! command -v openssl &>/dev/null; then
    echo -e "${RED}openssl not be found. Exit${NC}"
    exit
fi

#Flags:
# req               request
#-x509              sign
#-batch             no interactive
#-days              num of days it is valid
#-key               what key to use
#-subj              pass parameters that would have been interactive
#-nodes             means no des. Will not encrypt the private key. No passphrase
#-newkey            while request generation generate a new private key instead of using an existing
#-keout             path where to store the new generated key
#-key               path to keyfile to use for request or sign
#-out               path where to store the generated file
#-CA                path of CA tu use for signing
#-CAkey             path of CA pvt  key
#-CAcreateserial    set serialnumber of the signed. Used with-set_serial 01. OPTIONAL
#-config            path of a openssl.conf file with mor options. Moe in the info in openssl.conf. Default is in /etc/ssl/openssl.conf
#-extensions        Used for v3_req with the SAN option

#Create DST-folder
if [ ! -f "$DHPARAM_FILE" ]; then
    echo "Creating dhparam..."
    openssl dhparam -out $DHPARAM_FILE 2048
fi

# CA-cert
# Only generate ca if it does not exist or force override is set
if [ ! -f "$DST_DIR/$CA_FILE_NAME.$CERT_FILE_EXTENTION" ] || [ "$FORCE_CA_OVERRIDE" = "yes" ]; then
    # CA-key
    echo -e "${GRN}Creating CA key${NC}"
    # Create a private rsa key with the size of KEY_SIZE
    openssl genrsa -out $DST_DIR/$CA_FILE_NAME.key $KEY_SIZE

    # CA-cert
    openssl req -new -key $DST_DIR/$CA_FILE_NAME.key -x509 -days $CA_VALID_DAYS -batch -subj "/CN=${CA_CN}/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_CITY}/O=${CA_ORG}/OU=${CA_ORG_UNIT}/emailAddress=${CA_MAIL}" -out $DST_DIR/$CA_FILE_NAME.$CERT_FILE_EXTENTION
    # Convert for windows
    openssl pkcs12 -export -inkey $DST_DIR/$CA_FILE_NAME.key -in $DST_DIR/$CA_FILE_NAME.$CERT_FILE_EXTENTION -out $DST_DIR/$CA_FILE_NAME.pfx -passout pass:$PFX_EXPORT_PW
fi

# Clients
for client in ${CLIENTS[@]}; do
    echo -e "${GRN}Creating ${client} key and sign request ${NC}"
    openssl req -new -newkey rsa:$KEY_SIZE -nodes -keyout $DST_DIR/$client.key -batch -out $DST_DIR/$client.csr -config openssl.conf -subj "/CN=${client}/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${ORG_UNIT}/emailAddress=${client}@${ORG}.${COUNTRY,,}"

    # Sign with CA & keep subject alatanative names
    echo -e "${GRN}Signing ${client} with CA ${NC}"
    openssl x509 -req -days $CLIENT_VALID_DAYS -in $DST_DIR/$client.csr -CA $DST_DIR/$CA_FILE_NAME.$CERT_FILE_EXTENTION -CAkey $DST_DIR/$CA_FILE_NAME.key -CAcreateserial -set_serial 01 -out $DST_DIR/$client.$CERT_FILE_EXTENTION -extfile openssl.conf -extensions v3_req

    cat $DST_DIR/$client.$CERT_FILE_EXTENTION $DST_DIR/$CA_FILE_NAME.$CERT_FILE_EXTENTION >$DST_DIR/$client-full.$CERT_FILE_EXTENTION
done

# Debug helper: https://www.sslshopper.com/article-most-common-openssl-commands.html

# To install the CA do:
# sudo cp certificates/ca.$CERT_FILE_EXTENTION /usr/local/share/ca-certificates/my-ca-cert.crt
# sudo update-ca-certificates
# Windows import
# https://community.spiceworks.com/how_to/1839-installing-self-signed-ca-certificate-in-windows

# # Not signed server
# echo -e "${GRN}Not signed server${NC}"
# openssl genrsa -out $DST_DIR/NoSignedServer.key $KEY_SIZE
# openssl req -new -key $DST_DIR/NoSignedServer.key -x509 -days 3650 -batch -subj "/CN=NoSignServer-969272/C=DE/ST=LowerSaxony/L=Osnabrueck/O=UNI/OU=StudentSigner/emailAddress=hegerdes@uos.de" -out $DST_DIR/NoSignedServer.$CERT_FILE_EXTENTION

# # Not signed client
# echo -e "${GRN}Not signed client${NC}"
# openssl genrsa -out $DST_DIR/NoSignedClient.key $KEY_SIZE
# openssl req -new -key $DST_DIR/NoSignedClient.key -x509 -days 3650 -batch -subj "/CN=NoSignClient-969272/C=DE/ST=LowerSaxony/L=Osnabrueck/O=UNI/OU=StudentSigner/emailAddress=hegerdes@uos.de" -out $DST_DIR/NoSignedClient.$CERT_FILE_EXTENTION

# # Bad SubjectAltNames
# echo -e "${GRN}Bad SAN${NC}"
# openssl req -new -newkey rsa:$KEY_SIZE -nodes -keyout $DST_DIR/badSAN.key -batch -out $DST_DIR/badSAN.csr -config openssl_bad.conf -subj "/CN=${client}-969272/C=DE/ST=LowerSaxony/L=Osnabrueck/O=UNI/OU=${client}/emailAddress=${client}@uos.de"

# # Sign with CA & keep subject alatanative names
# openssl x509 -req -days 365 -in $DST_DIR/badSAN.csr -CA $DST_DIR/$CA_FILE_NAME.$CERT_FILE_EXTENTION -CAkey $DST_DIR/$CA_FILE_NAME.key -CAcreateserial -set_serial 01 -out $DST_DIR/badSAN.$CERT_FILE_EXTENTION -extfile openssl_bad.conf -extensions v3_req

echo -e "${GRN}Everything generated succsesfully${NC}"
