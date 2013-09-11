#! /usr/bin/env bash

set -a 
source /opt/meddle/meddle.config
inpName=$1
dumpName=$2
${gpgBinPath} --homedir=${gpgHome} -o ${dumpName} --keyring ${gpgPublicKeyRing} -er ${gpgPublicKeyID} --trust-model always ${inpName}
