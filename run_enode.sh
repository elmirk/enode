#!/bin/bash
docker run -dit --log-driver=json-file --log-opt max-size=10m --log-opt max-file=15 -e SMSR_TCAP_ODLGS_NUM -e SMSR_TCAP_IDLGS_NUM --name=enode --network="host" enode:0.0.0
 
