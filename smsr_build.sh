#!/bin/bash

#author: elmir.karimullin@gmail.com
#script used to start smsr (as 3 docker containers) manually
#ordered start used - enode, ss7, cnode

#SCRIPT USAGE:
#to start smsr in production use:
# smsr_start.sh -d 16000 -s PROD
#to start smsr in dev use:
# smsr_start.sh -d 16000 -s DEV

# -c Contaiers: all | enode | ss7 | cnode
# -d Dialogues number (use 16000 for outgoing and incoming dlgs)
# -s Stage = DEV | PROD (PRODuction | DEVeloping)

#NOTES:
#
#1. not used --rm option in docker run,so when DOCKER STOP SS7 used to stop container
#then container not deleted, should delete container by DOCKER RM SS7 before run it again by this script
#2. if you delete container then you couldn't use DOCKER LOGS SS7 to fetch container logs
#3. containers run order - enode, ss7 and then cnode.

#when use ELK
#docker run -it --log-driver gelf --log-opt gelf-address=tcp://localhost:5000 -e DIALOGIC_STAGE=DEV --rm --name=dialogic --ipc="host" --network="host" dialogic:0.0.0 bash

#set -e

usage() { echo "Usage: $0 [-c <all | enode | ss7 | cnode>] [-v <VERSION>] [-f <string>]" 1>&2; exit 1; }

while getopts ":c:v:" o; do
    case "${o}" in
        c)
            CONTAINER=${OPTARG}
            ;;
        v)
            #s=${OPTARG}
            #((s == 45 || s == 90)) || usage
            VERSION="${OPTARG}"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

docker build -t ${CONTAINER}:${VERSION} --build-arg GIT_COMMIT=$(git rev-parse --short HEAD) .

echo "container ss7 build finished OK..."
