unset GREP_OPTIONS
while read p; do

printf "
- type: http
  id: \"$p\"
  name: \"HTTP Host: $p\"
  schedule: '@every 5s'
  hosts: [\"https://$p\"]
  ssl.verification_mode: none
  check.request.method: HEAD
  check.response.status: [200, 301, 302, 401]  
"

done </tmp/routelist


---
apiVersion: v1
kind: ConfigMap
metadata:
  name: heartbeat-deployment-config
  namespace: lsdmop
  labels:
    k8s-app: heartbeat
data:
  heartbeat.yml: |-
    #heartbeat.autodiscover:
    #  # Autodiscover pods
    #  providers:
    #    - type: kubernetes
    #      resource: pod
    #      scope: cluster
    #      node: ${NODE_NAME}
    #      hints.enabled: true
    #
    #  # Autodiscover services
    #  providers:
    #    - type: kubernetes
    #      resource: service
    #      scope: cluster
    #      node: ${NODE_NAME}
    #      hints.enabled: true
    #
    #  # Autodiscover nodes
    #  providers:
    #    - type: kubernetes
    #      resource: node
    #      node: ${NODE_NAME}
    #      scope: cluster
    #      templates:
    #        # Example, check SSH port of all cluster nodes:
    #        - condition: ~
    #          config:
    #            - hosts:
    #                - ${data.host}:22
    #              name: ${data.kubernetes.node.name}
    #              schedule: '@every 10s'
    #              timeout: 5s
    #              type: tcp


    processors:
      - add_cloud_metadata:

    cloud.id: ${ELASTIC_CLOUD_ID}
    cloud.auth: ${ELASTIC_CLOUD_AUTH}

    output.elasticsearch:
      hosts: ['${ELASTICSEARCH_HOST:elasticsearch}:${ELASTICSEARCH_PORT:9200}']
      username: ${ELASTICSEARCH_USERNAME}
      password: ${ELASTICSEARCH_PASSWORD}
---