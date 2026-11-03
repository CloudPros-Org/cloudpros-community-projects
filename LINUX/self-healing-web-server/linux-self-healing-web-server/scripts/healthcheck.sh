#!/bin/bash
mkdir -p /var/log/cloudpros/

ip="127.0.0.1"
port="8000"
URL="http://${ip}:${port}/"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

response_code=$(curl --write-out '%{http_code}' --silent --output /dev/null "${URL}")
echo "HTTP Status Code: $response_code"


if [ "$response_code" -eq 200 ]; then
	echo "[$TIMESTAMP] : SUCCESS $response_code" >> "/var/log/cloudpros/cloudproshealthlogs.logs"
else  	
	echo "[$TIMESTAMP] : FAILED $response_code" >> "/var/log/cloudpros/cloudproshealthlogs.logs"
	systemctl restart cloud-pros.service
fi

