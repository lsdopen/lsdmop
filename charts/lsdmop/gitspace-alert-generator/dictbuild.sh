#!/bin/bash

# Configuration
ES_USERNAME=${1}
ES_PASSWORD=${2}
ES_HOSTNAME=${3}

cleanup() {
    # apt update && apt install jq curl wget

    # wget https://github.com/openshift/okd/releases/download/4.5.0-0.okd-2020-07-14-153706-ga/openshift-client-linux-4.5.0-0.okd-2020-07-14-153706-ga.tar.gz
    # tar -xvf openshift-client-linux-4.5.0-0.okd-2020-07-14-153706-ga.tar.gz
    # mv oc kubectl /usr/local/bin/

    rm -f ./bulk-prd ./bulk-tst ./bulk-dev
}

get_team_from_rc() {
    local nsp="$1"
    local rc="$2"
    
    json=$(oc get rc $rc --namespace $nsp -ojson)
    local checkteam=$(echo "$json" | jq -cr '.metadata.labels.team')
    
    if [[ $checkteam == null ]]; then
        echo -e ">>> No label on RC: $rcp"
    elif [[ $checkteam == 'UNKNOWN' ]]; then
        echo -e ">>> Discard label on RC: $rcp Team: $checkteam"
    else
        echo -e ">>> Found label on RC: $rcp: Team: $checkteam"
        team="$checkteam"
    fi
}

generate_payload_entries() {
    local id="$1"
    local nsp="$2"
    local team="$3"
    
    echo '{ "index" : { "_index" : "enrich-team-name-2", "_id" : "'$id'" } }' | jq -c
    echo '{ "namespace" : "'$nsp'", "team" : "'$team'" }' | jq -c
}

load_data_to_elasticsearch() {
    local file="$1"
    
    curl -sk -XPOST "https://$ES_USERNAME:$ES_PASSWORD@$ES_HOSTNAME/_bulk" -H "Content-Type: application/x-ndjson" --data-binary @"$file" > /dev/null
}

refresh_elasticsearch_index() {
    curl -XPOST "https://$ES_USERNAME:$ES_PASSWORD@$ES_HOSTNAME/enrich-team-name-2/_refresh" -H "kbn-xsrf: reporting"
}

execute_enrichment_policy() {
    curl -XPUT "https://$ES_USERNAME:$ES_PASSWORD@$ES_HOSTNAME/_enrich/policy/enrich-team-policy/_execute" -H "kbn-xsrf: reporting"
}

main() {
    cleanup

    for nsp in $(oc get ns | awk '{print $1}' | grep prd | sort); do
        echo -e "======= Get label from NS: $nsp"
        
        json=$(oc get ns $nsp -ojson)
        team=$(echo "$json" | jq -cr '.metadata.labels.team')
        
        if [[ $team == null ]]; then
            echo -e ">> No label on NS: $nsp"
            
            for rcp in $(oc get rc --namespace $nsp --no-headers | awk '{print $1}'); do
                echo -e ">> Get label from RC: $rcp"
                get_team_from_rc "$nsp" "$rcp"
            done
            
            if [[ $team == null ]]; then
                echo -e "> Unable to determine team by any means"
                echo -e "======= END ATTEMPT\n"
                team='UNKNOWN'
            fi
        else
            echo -e ">> Found label on NS: $nsp"
        fi
        
        echo -e "- Revalidating value of team: $team"
        
        # Generate IDs using md5sum and namespace
        idp=$(echo "$nsp" | md5sum | head -c 16)
        
        # Set idt and idd before calculating nst and nsd
        idt="$idp"
        idd="$idp"
        
        nst=$(echo "$nsp" | sed 's/prd-/tst-/g')
        idt=$(echo "$nst" | md5sum | head -c 16)
        
        nsd=$(echo "$nsp" | sed 's/prd-/dev-/g')
        idd=$(echo "$nsd" | md5sum | head -c 16)
        
        # Generate payload entries
        generate_payload_entries "$idp" "$nsp" "$team" >> bulk-prd
        generate_payload_entries "$idt" "$nst" "$team" >> bulk-tst
        generate_payload_entries "$idd" "$nsd" "$team" >> bulk-dev
        
        echo -e "> Success"
        echo -e "Namespace: $nsp"
        echo -e "Team     : $team"
        echo -e "======= END ATTEMPT\n"
    done

    echo -e '\n' >> bulk-prd
    echo -e '\n' >> bulk-tst
    echo -e '\n' >> bulk-dev

    #exit 0 #DEBUG

    load_data_to_elasticsearch "bulk-prd"
    load_data_to_elasticsearch "bulk-tst"
    load_data_to_elasticsearch "bulk-dev"

    refresh_elasticsearch_index

    echo -e '\n\nWait 5 seconds...\n'
    sleep 5

    execute_enrichment_policy

    echo -e '\n\n============ DONE =============\n'
    exit 0
}

main "$@"
