spaces=${1}
esusername=${2}
espassword=${3}
kbhostname=${4}
matchstring=${5}
action=${6}
#sleep 30000

#echo $action

if [[ $action != 'enable' && $action != 'disable' ]]
then 
  echo "Action must be enable or disable"
  exit 1
fi


for space in ${spaces}; do for rule in $(curl -k "https://${esusername}:${espassword}@${kbhostname}/s/${space,,}/api/alerting/rules/_find?search_fields=name&per_page=1000&search=PRD*${matchstring}&default_search_operator=AND" | jq -r '.data[].id'); do curl -k -XPOST "https://${esusername}:${espassword}@${kbhostname}/s/${space,,}/api/alerting/rule/${rule}/_${action}" -H 'kbn-xsrf: true'; done; done