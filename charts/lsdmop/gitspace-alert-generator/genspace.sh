#!/bin/bash

# Generator for Space onboarding for a Team - also sets up some basic alerts, security, dashboards, and an Email Connector
# Version 1.1.b.230224.1
#
# Usage: ./genspacealert.sh <teamname> "<adminDN>" "<userDN>" <user> <password> <eshostname> <kbhostname>
# AD Group DNs *must* be double quoted else JSON payloads won't be valid JSON

# Eg: 

#TODO:
# 1) Implement usage output when no cmd line args
# 2) Combine gen and del scripts into one where selection can be made via a cmd --mode param
# 3) Handle case when there are multiple connectors, not just an EMAIL type connector
# 4) ...
# x) ...
# ?) TBD: This would be much better in Python - only considered the real edge-cases and complexity when working on it


#CONFIG PARAMETERS
# esusername="elastic"
# espassword="r6qD45394OK6zKrjwbf8q69n"
# eshostname="localhost:9200"
# kbhostname="localhost:5601"

esusername=${4}
espassword=${5}
eshostname=${6}
kbhostname=${7}
#



# SET USER PASS AND HOSTNAME VARS (OPTIONAL UNCOMMENT TO USE - OVERRIDES CONFIG PARAMS ABOVE)
# unset esusername
# unset espassword
# echo -n "Username:"
# read esusername
# echo
# echo "Password:"
# read -s espassword
# echo

# NOT USED, LEFT IN PLACE FOR REFERENCE
#UUIDCONN=$(uuidgen)
#echo $UUIDCONN


#DEBUGGING STUFF
# eval string1="$1"
# eval string2="$2"
# eval string3="$3"

# echo "string1 = ${string1}"
# echo "string2 = ${string2}"
# echo "string3 = ${string3}"
#Check input parameter values
echo $1
echo $2
echo $3
echo $4
echo $5
echo $6
echo $7
echo $8



### SETUP SPACE ###

echo -e "======= Create Space for '${1}' =======\n"
curl -sk -XPOST "https://$esusername:$espassword@$kbhostname/api/spaces/space" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
{
  "id": "'${1,,}'",
  "name": "'${1}'",
  "description" : "This is the '${1}' Space",
  "disabledFeatures": []
}
'
echo -e "\n"





### SETUP SECURITY ###

### Admin Role ###
echo -e "======= Create an Admin User Role For '${1}' Users =======\n"
curl -k -XPOST "https://$esusername:$espassword@$eshostname/_security/role/${1,,}_admin_role" -H 'Content-Type: application/json' -d'
{
    "cluster": [],
    "indices": [
      {
        "names": [
          "metricbeat-*",
          "metrics-*",
          "filebeat-*",
          "logs-*",
          "traces-*",
          "traces-apm*,apm-*,logs-apm*,apm-*,metrics-apm*,apm-*",
          "(rum-data-view)*,traces-apm*,apm-*,logs-apm*,apm-*,metrics-apm*,apm-*"
        ],
        "privileges": [
          "read",
          "read_cross_cluster",
          "view_index_metadata",
          "monitor"
        ],
        "field_security": {
          "grant": [
            "*"
          ],
          "except": []
        },
        "allow_restricted_indices": false
      }
    ],
    "applications": [
      {
        "application": "kibana-.kibana",
        "privileges": [
          "space_all"
        ],
        "resources": [
          "space:'${1}'"
        ]
      }
    ]
  }
'

echo -e "\n"
echo -e "======= Create an Admin Role Mapping for '${1}' =======\n"
curl -k -XPOST "https://$esusername:$espassword@$eshostname/_security/role_mapping/${1,,}_admin_user" -H 'Content-Type: application/json' -d'
{
    "enabled": true,
    "roles": [
      "superuser", "'${1,,}'_admin_role", "reporting_user"
    ],
    "rules": {
      "field": {
        "groups": "'"$2"'"
      }
    },
    "metadata": {}
  
}
'
echo -e "\n"

### Basic Role ###
echo -e "======= Create a Basic User Role For '${1}' Users =======\n"
curl -k -XPOST "https://$esusername:$espassword@$eshostname/_security/role/${1,,}_user_role" -H 'Content-Type: application/json' -d'
{
    "cluster": [],
    "indices": [
      {
        "names": [
          "metricbeat-*",
          "metrics-*",
          "filebeat-*",
          "logs-*",
          "traces-*",
          "traces-apm*,apm-*,logs-apm*,apm-*,metrics-apm*,apm-*",
          "(rum-data-view)*,traces-apm*,apm-*,logs-apm*,apm-*,metrics-apm*,apm-*"
        ],
        "privileges": [
          "read",
          "read_cross_cluster",
          "view_index_metadata",
          "monitor"
        ],
        "field_security": {
          "grant": [
            "*"
          ],
          "except": []
        },
        "allow_restricted_indices": false
      }
    ],
    "applications": [
      {
        "application": "kibana-.kibana",
        "privileges": [
          "space_all"
        ],
        "resources": [
          "space:'${1}'"
        ]
      }
    ]
  }
'
echo -e "\n"

### Mapping basic role onto a specified AD Group ###
echo -e "======= Create a Basic User Role Mapping =======\n"
curl -k -XPOST "https://$esusername:$espassword@$eshostname/_security/role_mapping/${1,,}_basic_user" -H 'Content-Type: application/json' -d'
{
    "enabled": true,
    "roles": [
      "'${1,,}'_user_role", "default_user", "reporting_user"
    ],
    "rules": {
      "field": {
        "groups": "'"$3"'"
      }
    },
    "metadata": {}
  
}
'
echo -e "\n"


# echo -e "======= Create Connector in Space ${1} =======\n"


# echo -e "### Checking if Email connector exists\n"
# CONNCOUNT=$(curl -sk "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/actions/connectors" '.[].id' | sed s/\"//g | wc -l)
# if [[ $CONNCOUNT -eq 0 ]]
# then
#    ### Create an Alert Connector of type email ###
#    echo -e "======= Create Connector in Space ${1} =======\n"
#    curl -sk -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/actions/connector" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
#    {
#    "name": "O365-SMTP",
#    "config": {
#       "from": "noreply@localhost",
#       "service": "outlook365",
#       "host": "smtp.office365.com",
#       "port": 587,
#       "secure": false
#    },
#    "connector_type_id": ".email"
#    }
#    '
#    echo -e "\n"
# else
#    echo -e "### Connector already exists\n"
# fi


# echo -e "======= Get Connector ID =======\n"
# UUID=$(curl -sk "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/actions/connectors" '.[].id' | sed s/\"//g)

# echo "Connector ID is: '$UUID'
# "
# echo -e "\n"




### END RULES GENERATORS ###


### Object Loaders ###
echo -e "=======  Loading Objects ======== \n"

sed -i 's;\"XXXABABXXX\\\";\"'${1}'\\\";g' ./unifieddash.ndjson
sed -i 's;\"XXXABABXXX\\\";\"'${1}'\\\";g' ./globalobjects.ndjson
sed -i 's;\/s\/xxxababxxx\/;\/s\/'${1,,}'\/;g' ./globalobjects.ndjson
sed -i 's;\"XXXABABXXX\\\";\"'${1}'\\\";g' ./inventoryview.ndjson
sed -i 's;\"XXXABABXXX\";\"'${1}'\";g' ./inventoryview.ndjson
sed -i 's;\"XXXABABXXX\\\";\"'${1}'\\\";g' ./explorerview.ndjson
sed -i 's;\"XXXABABXXX\\\";\"'${1}'\\\";g' ./savedsearchlogs.ndjson
sed -i 's;\"XXXABABXXX Logs\";\"'${1}' Logs\";g' ./savedsearchlogs.ndjson


#These curl commands must be spaced by one newline else bash does weird stuff and says XPOST is not a valid command
echo -e "### Load dataviews ###\n"

curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/saved_objects/_import?overwrite=true" -H 'kbn-xsrf: true' --form file=@dataviews.ndjson

echo -e "### Load Kafkadash ###\n" #disabled

#curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/saved_objects/_import?overwrite=true" -H 'kbn-xsrf: true' --form file=@kafkadash.ndjson

echo -e "### Load Unifieddash ###\n"

curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/saved_objects/_import?overwrite=true" -H 'kbn-xsrf: true' --form file=@unifieddash.ndjson

# curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/saved_objects/_import?overwrite=true" -H 'kbn-xsrf: true' --form file=@globaldash.ndjson

# curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/saved_objects/_import?overwrite=true" -H 'kbn-xsrf: true' --form file=@globaldashalerts.ndjson

echo -e "### Load Saved Search Logs ###\n"

curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/saved_objects/_import?overwrite=true" -H 'kbn-xsrf: true' --form file=@savedsearchlogs.ndjson

echo -e "### Load Inventory View ###\n"

curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/saved_objects/_import?overwrite=true" -H 'kbn-xsrf: true' --form file=@inventoryview.ndjson

echo -e "### Load Explorer View ###\n"

curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/saved_objects/_import?overwrite=true" -H 'kbn-xsrf: true' --form file=@explorerview.ndjson

echo -e "### Load Globaldash Objects ###\n"

curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${1,,}/api/saved_objects/_import?overwrite=true" -H 'kbn-xsrf: true' --form file=@globalobjects.ndjson



sed -i 's;\"'${1}'\\\";\"XXXABABXXX\\\";g' ./unifieddash.ndjson
sed -i 's;\"'${1}'\\\";\"XXXABABXXX\\\";g' ./globalobjects.ndjson
sed -i 's;\/s\/'${1,,}'\/;\/s\/xxxababxxx\/;g' ./globalobjects.ndjson
sed -i 's;\"'${1}'\\\";\"XXXABABXXX\\\";g' ./inventoryview.ndjson
sed -i 's;\"'${1}'\";\"XXXABABXXX\";g' ./inventoryview.ndjson
sed -i 's;\"'${1}'\\\";\"XXXABABXXX\\\";g' ./explorerview.ndjson
sed -i 's;\"'${1}'\\\";\"XXXABABXXX\\\";g' ./savedsearchlogs.ndjson
sed -i 's;\"'${1}' Logs\";\"XXXABABXXX Logs\";g' ./savedsearchlogs.ndjson

### End Object Loaders ###