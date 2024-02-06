space=${1}
version=${2}
esusername=${3}
espassword=${4}
eshostname=${5}
kbhostname=${6}

if [[ $version == '' ]]
then
  echo "Please specify version"
  exit 0
fi

if [[ $space == '' ]]
then
  echo "Please specify space"
  exit 0
fi

for space in ${space}; do for rule in $(curl -k "https://$esusername:$espassword@$kbhostname/s/${space,,}/api/alerting/rules/_find?search_fields=name&per_page=1000&search=*${version}" | jq -r '.data[].id'); do curl -k -XDELETE "https://$esusername:$espassword@$kbhostname/s/${space,,}/api/alerting/rule/${rule}" -H 'kbn-xsrf: true'; done; done