#!/bin/bash

set -e

if [ "$(id -u)" = '0' ] #First run as root (it switches later to zookeeper user)
then
	echo "Fixing resolv.conf as root"
 	sleep 15 && sed -e "s/^search/& $(dnsdomainname)/" /etc/resolv.conf > /tmp/resolv.conf;cat /tmp/resolv.conf  > /etc/resolv.conf
fi



INDEX=${HOSTNAME##*-}

echo "My index = $INDEX"
MY_ID=$((INDEX+1))
echo "My ID = $MY_ID" 

# Get ordinal ID and set in myid file
echo $MY_ID > "$ZOO_DATA_DIR/myid"


SERVER_PORT=2888
ELECTION_PORT=3888
CLIENT_PORT=2181

populate_peers() {

	HOSTNAME_BASE=`echo $HOSTNAME | rev  | (read HOSTNAME_TEMP && echo ${HOSTNAME_TEMP#*-} | rev)`
	echo $HOSTNAME_BASE
	
	for ((n=0;n<$CLUSTER_SIZE;n++))
	do
		SERVER_NUMBER=$((n+1))
	
		if [ "$n" -eq "$INDEX" ]
		then
			SERVER_ENTRY="server.$SERVER_NUMBER=0.0.0.0:$SERVER_PORT:$ELECTION_PORT;$CLIENT_PORT"
		else
			SERVER_ENTRY="server.$SERVER_NUMBER=$HOSTNAME_BASE-$n:$SERVER_PORT:$ELECTION_PORT;$CLIENT_PORT"
		fi
		echo "$SERVER_ENTRY" >> $CONFIG""
	done
 }


configure_tls() {

	echo 'sslQuorum=true' >> $CONFIG
	echo 'serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory' >> $CONFIG
	echo 'ssl.quorum.keyStore.location='$KEYSTORE_ROOTPATH$INDEX'/zookeeper-'$INDEX'-keystore.jks' >> $CONFIG
	echo 'ssl.quorum.keyStore.password='$KEYSTORE_PASSWORD >> $CONFIG
	echo 'ssl.quorum.trustStore.location='$TRUSTSTORE_PATH >> $CONFIG
	echo 'ssl.quorum.trustStore.password='$TRUSTSTORE_PASSWORD >> $CONFIG

}





# Allow the container to be started with `--user`
if [[ "$1" = 'zkServer.sh' && "$(id -u)" = '0' ]]; then
    chown -R zookeeper "$ZOO_DATA_DIR" "$ZOO_DATA_LOG_DIR" "$ZOO_LOG_DIR" "$ZOO_CONF_DIR"
    exec gosu zookeeper "$0" "$@"
fi



# Generate the config only if it doesn't exist
if [[ ! -f "$ZOO_CONF_DIR/zoo.cfg" ]]; then
    CONFIG="$ZOO_CONF_DIR/zoo.cfg"

    echo "dataDir=$ZOO_DATA_DIR" >> "$CONFIG"
    echo "dataLogDir=$ZOO_DATA_LOG_DIR" >> "$CONFIG"

    echo "tickTime=$ZOO_TICK_TIME" >> "$CONFIG"
    echo "initLimit=$ZOO_INIT_LIMIT" >> "$CONFIG"
    echo "syncLimit=$ZOO_SYNC_LIMIT" >> "$CONFIG"

    echo "autopurge.snapRetainCount=$ZOO_AUTOPURGE_SNAPRETAINCOUNT" >> "$CONFIG"
    echo "autopurge.purgeInterval=$ZOO_AUTOPURGE_PURGEINTERVAL" >> "$CONFIG"
    echo "maxClientCnxns=$ZOO_MAX_CLIENT_CNXNS" >> "$CONFIG"
    echo "standaloneEnabled=$ZOO_STANDALONE_ENABLED" >> "$CONFIG"
    echo "admin.enableServer=$ZOO_ADMINSERVER_ENABLED" >> "$CONFIG"

    if [[ -z $ZOO_SERVERS ]]; then
      ZOO_SERVERS="server.1=localhost:2888:3888;2181"
    fi

  #  for server in $ZOO_SERVERS; do
   #     echo "$server" >> "$CONFIG"
   # done

    populate_peers

#    configure_tls

    if [[ -n $ZOO_4LW_COMMANDS_WHITELIST ]]; then
        echo "4lw.commands.whitelist=$ZOO_4LW_COMMANDS_WHITELIST" >> "$CONFIG"
    fi

fi

exec "$@"
