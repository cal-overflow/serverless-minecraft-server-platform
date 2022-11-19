#!/bin/bash

## Required Environment Variables

[ -n "$CLUSTER" ] || { echo "CLUSTER env variable must be set to the name of the ECS cluster" ; exit 1; }
[ -n "$SERVICE" ] || { echo "SERVICE env variable must be set to the name of the service in the $CLUSTER cluster" ; exit 1; }
[ -n "$SERVER_NAME" ] || { echo "SERVER_NAME env variable must be set to the name of the server" ; exit 1; }
[ -n "$DNS_ZONE" ] || { echo "DNS_ZONE env variable must be set to the Route53 Hosted Zone ID" ; exit 1; }
[ -n "$START_UP_MIN" ] || { echo "START_UP_MIN env variable not set, defaulting to a 10 minute startup wait" ; START_UP_MIN=10; }
[ -n "$SHUT_DOWN_MIN" ] || { echo "SHUT_DOWN_MIN env variable not set, defaulting to a 20 minute shutdown wait" ; SHUT_DOWN_MIN=20; }

SERVER_DOMAIN="$SERVER_NAME.mc.smarterservers.net"

function zero_service() {
  shutdown
  echo Setting desired task count to zero.
  aws ecs update-service --cluster $CLUSTER --service $SERVICE --desired-count 0
  exit 0
}

function sigterm() {
  ## upon SIGTERM set the service desired count to zero
  echo "Received SIGTERM, terminating task..."
  zero_service
}
trap sigterm SIGTERM

## get task id from the Fargate metadata
TASK=$(curl -s ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -r '.TaskARN' | awk -F/ '{ print $NF }')
echo I believe our task id is $TASK

## get eni from from ECS
ENI=$(aws ecs describe-tasks --cluster $CLUSTER --tasks $TASK --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value | [0]" --output text)
echo I believe our eni is $ENI

## get public ip address from EC2
PUBLICIP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
echo "I believe our public IP address is $PUBLICIP"

## update public dns record
echo "Updating DNS record for $SERVER_DOMAIN to $PUBLICIP"
## prepare json file
cat << EOF >> minecraft-dns.json
{
  "Comment": "Public IP change for Minecraft Server",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$SERVER_DOMAIN",
        "Type": "A",
        "TTL": 30,
        "ResourceRecords": [
          {
            "Value": "$PUBLICIP"
          }
        ]
      }
    }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $DNS_ZONE --change-batch file://minecraft-dns.json

## detemine java or bedrock based on listening port
echo "Determining Minecraft edition based on listening port..."
echo "If we are stuck here, the minecraft container probably failed to start.  Waiting 10 minutes just in case..."
COUNTER=0
while true
do
  netstat -atn | grep :25565 | grep LISTEN && EDITION="java" && break
  netstat -aun | grep :19132 && EDITION="bedrock" && break
  sleep 1
  COUNTER=$(($COUNTER + 1))
  if [ $COUNTER -gt 600 ] ## server has not been detected as starting within 10 minutes
  then
    echo 10 minutes elapsed without a minecraft server listening, terminating.
    zero_service
  fi
done
echo "Detected $EDITION edition"

if [ "$EDITION" == "java" ]
then
  echo "Waiting for Minecraft RCON to begin listening for connections..."
  STARTED=0
  while [ $STARTED -lt 1 ]
  do
    CONNECTIONS=$(netstat -atn | grep :25575 | grep LISTEN | wc -l)
    STARTED=$(($STARTED + $CONNECTIONS))
    if [ $STARTED -gt 0 ] ## minecraft actively listening, break out of loop
    then
      echo "RCON is listening, we are ready for clients."
      break
    fi
    sleep 1
  done
fi

if [ "$EDITION" == "bedrock" ]
then
  PINGA="\x01" ## uncommitted ping
  PINGB="\x00\x00\x00\x00\x00\x00\x4e\x20" ## time since start in ms.  20 seconds sounds good
  PINGC="\x00\xff\xff\x00\xfe\xfe\xfe\xfe\xfd\xfd\xfd\xfd\x12\x34\x56\x78" ## offline message data id
  PINGD=$(for i in $(seq 1 8); do echo -en "\x5c\x78" ; tr -dc 'a-f0-9' < /dev/urandom | head -c2; done) ## random client guid
  BEDROCKPING=$PINGA$PINGB$PINGC$PINGD
  echo "Bedrock ping string is $BEDROCKPING"
fi


startup

echo "Checking every 1 minute for active connections to Minecraft, up to $START_UP_MIN minutes..."
COUNTER=0
CONNECTED=0
while [ $CONNECTED -lt 1 ]
do
  echo Waiting for connection, minute $COUNTER out of $START_UP_MIN...
  [ "$EDITION" == "java" ] && CONNECTIONS=$(netstat -atn | grep :25565 | grep ESTABLISHED | wc -l)
  [ "$EDITION" == "bedrock" ] && CONNECTIONS=$((echo -en "$BEDROCKPING" && sleep 1) | ncat -w 1 -u 127.0.0.1 19132 | cut -c34- | awk -F\; '{ print $5 }')
  [ -n "$CONNECTIONS" ] || CONNECTIONS=0
  CONNECTED=$(($CONNECTED + $CONNECTIONS))
  COUNTER=$(($COUNTER + 1))
  if [ $CONNECTED -gt 0 ] ## at least one active connection detected, break out of loop
  then
    break
  fi
  if [ $COUNTER -gt $START_UP_MIN ] ## no one has connected in at least these many minutes
  then
    echo $START_UP_MIN minutes exceeded without a connection, terminating.
    zero_service
  fi
  ## only doing short sleeps so that we can catch a SIGTERM if needed
  for i in $(seq 1 59) ; do sleep 1; done
done

echo "We believe a connection has been made, switching to shutdown watcher."
COUNTER=0
while [ $COUNTER -le $SHUT_DOWN_MIN ]
do
  [ "$EDITION" == "java" ] && CONNECTIONS=$(netstat -atn | grep :25565 | grep ESTABLISHED | wc -l)
  [ "$EDITION" == "bedrock" ] && CONNECTIONS=$((echo -en "$BEDROCKPING" && sleep 1) | ncat -w 1 -u 127.0.0.1 19132 | cut -c34- | awk -F\; '{ print $5 }')
  [ -n "$CONNECTIONS" ] || CONNECTIONS=0
  if [ $CONNECTIONS -lt 1 ]
  then
    echo "No active connections detected, $COUNTER out of $SHUT_DOWN_MIN minutes..."
    COUNTER=$(($COUNTER + 1))
  else
    [ $COUNTER -gt 0 ] && echo "New connections active, zeroing counter."
    COUNTER=0
  fi
  for i in $(seq 1 59) ; do sleep 1; done
done

echo "$SHUT_DOWN_MIN minutes elapsed without a connection, terminating."
zero_service

