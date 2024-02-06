#!/bin/bash

# Rollback for Space onboarding for a Team - also removes security config, basic alerts, and the Email Connector
# Version 1.0.b.230201.1

#SET USER PASS AND HOSTNAME VARS

# unset esusername
# unset espassword
# echo -n "Username:"
# read esusername
# echo
# echo "Password:"
# read -s espassword
# echo

#UUIDCONN=$(uuidgen)
#echo $UUIDCONN
space=${1}
doyoureallywantodelete=${2}
esusername=${3}
espassword=${4}
eshostname=${5}
kbhostname=${6}

if [[ $space == '' ]]
then
  echo "Please specify space"
  exit 1
fi

if [[ $doyoureallywantodelete != 'YES' && $doyoureallywantodelete != 'Yes' ]]
then
  echo "Please explicitly confirm by setting the confirm var to YES"
  exit 1
fi

#

curl -k -XDELETE "https://$esusername:$espassword@$eshostname/_security/role_mapping/${space,,}_admin_user?pretty"
curl -k -XDELETE "https://$esusername:$espassword@$eshostname/_security/role_mapping/${space,,}_basic_user?pretty"
curl -k -XDELETE "https://$esusername:$espassword@$eshostname/_security/role/${space,,}_admin_role?pretty"
curl -k -XDELETE "https://$esusername:$espassword@$eshostname/_security/role/${space,,}_user_role?pretty"
curl -k -XDELETE "https://$esusername:$espassword@$kbhostname/api/spaces/space/${space,,}" -H 'kbn-xsrf: true'