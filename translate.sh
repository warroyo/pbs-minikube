#!/bin/bash
MKPATH="$HOME/.minikube/"
MK=$(echo $MKPATH | sed 's/\//\\\//g')
CA=$(base64  "${MKPATH}ca.crt" | sed 's/\//\\\//g')
CRT=$(base64  "${MKPATH}client.crt" | sed 's/\//\\\//g')
KEY=$(base64  "${MKPATH}client.key" | sed 's/\//\\\//g')
cat ~/.kube/config | sed "s/: ${MK}ca\.crt/-data: ${CA}/g" | sed "s/: ${MK}client\.crt/-data: ${CRT}/g" | sed "s/: ${MK}client\.key/-data: ${KEY}/g"
