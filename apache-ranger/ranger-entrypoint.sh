#!/bin/sh

#---------------------------------------
#       Wait for dependencies
#---------------------------------------
until nc -z -v -w30 ranger-db 3306; do echo "Waiting for database connection..." && sleep 5; done
echo "Connected to MySQL DB"
until $(curl --output /dev/null --silent --head --fail http://solr3:8983); do echo "Waiting for SOLR" && sleep 5; done
echo "Solr now available"


#---------------------------------------
#
#       Configure Admin Service
#
#---------------------------------------
cd $RANGER_ADMIN_HOME
echo -e "\n\n\n    ****    Configuring and installing Ranger Admin    ****\n\n\n"

# # Point logging section to Solr Container
# sed -i 's|audit_store=solr|audit_store=none|' install.properties
sed -i 's|audit_solr_urls=|audit_solr_urls=http://solr3:8983/solr/ranger_auditing|' install.properties
sed -i 's|audit_solr_user=|audit_solr_user=solr|' install.properties
sed -i 's|audit_solr_password=|audit_solr_password=NONE|' install.properties

echo "Creating Solr Collection"
curl "http://solr1:8983/solr/admin/collections?action=CREATE&name=ranger_auditing&numShards=3&collection.configName=ranger_audits"
# curl --negotiate -u : "${SOLR_HOST_URL}/solr/admin/collections?action=CREATE&name=${COLLECTION_NAME}&numShards=${SHARDS}&replicationFactor=${REPLICATION}&collection.configName=$CONF_NAME&maxShardsPerNode=100"


# Configure DB
sed -i 's|db_root_password=|db_root_password=password|' install.properties
sed -i 's|db_root_user=root|db_root_user=admin|' install.properties
sed -i 's|db_host=localhost|db_host=ranger-db|' install.properties
sed -i 's|db_password=|db_password=password|' install.properties

# Configure User Passwords
sed -i 's|rangerAdmin_password=|rangerAdmin_password=password1|' install.properties
sed -i 's|rangerTagsync_password=|rangerTagsync_password=password1|' install.properties
sed -i 's|rangerUsersync_password=|rangerUsersync_password=password1|' install.properties
sed -i 's|keyadmin_password=|keyadmin_password=password1|' install.properties

$RANGER_ADMIN_HOME/setup.sh


# #---------------------------------------
# #
# #       Configure TagSync Service
# #
# #---------------------------------------
cd $RANGER_TAGSYNC_HOME
echo -e "\n\n\n    ****    Configuring and installing Ranger TagSync    ****\n\n\n"

# # Configure TagSync to poll Atlas API
# sed -i 's|TAG_SOURCE_ATLAS_ENABLED = true|TAG_SOURCE_ATLAS_ENABLED = false|' install.properties
# sed -i 's|TAG_SOURCE_ATLASREST_ENABLED = false|TAG_SOURCE_ATLASREST_ENABLED = true|' install.properties
sed -i 's|TAG_SOURCE_ATLAS_KAFKA_BOOTSTRAP_SERVERS = localhost:6667|TAG_SOURCE_ATLAS_KAFKA_BOOTSTRAP_SERVERS = kafka1:19091,kafka2:19092,kafka3:19093|' install.properties
sed -i 's|TAG_SOURCE_ATLAS_KAFKA_ZOOKEEPER_CONNECT = localhost:2181|TAG_SOURCE_ATLAS_KAFKA_ZOOKEEPER_CONNECT = zookeeper:2181|' install.properties
sed -i 's|TAG_SOURCE_ATLAS_KAFKA_SECURITY_PROTOCOL = PLAINTEXTSASL|TAG_SOURCE_ATLAS_KAFKA_SECURITY_PROTOCOL = PLAINTEXT|' install.properties




$RANGER_TAGSYNC_HOME/setup.sh


#---------------------------------------
#       Start Services
#---------------------------------------
PATH=$PATH:$RANGER_TAGSYNC_HOME:$RANGER_ADMIN_HOME
ranger-admin start
ranger-tagsync start


#---------------------------------------
#       Keep the container running
#---------------------------------------
tail -f $RANGER_ADMIN_HOME/logfile $RANGER_TAGSYNC_HOME/log/tagsync.*
# tail -f $RANGER_ADMIN_HOME/logfile

