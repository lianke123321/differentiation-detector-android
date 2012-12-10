#!/bin/bash
#This script takes an IP address and spits out an IP -> Identity mapping
echo "Reading from file $1" 1>&2

cut -f1 $1 | sort | uniq | while read line; do echo "$line	$(whois $line | grep OrgName | sed 's/   */	/g' | cut -f2)"; done
