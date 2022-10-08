#!/bin/bash

set -euo pipefail

for CRD in $(kubectl get crds -o=name | grep "${GROUP}")
do
    kubectl label ${CRD} app.kubernetes.io/managed-by=Helm --overwrite
    kubectl annotate ${CRD} meta.helm.sh/release-name=${HELM_RELEASE} --overwrite
    kubectl annotate ${CRD} meta.helm.sh/release-namespace=${HELM_RELEASE_NAMESPACE} --overwrite
done
