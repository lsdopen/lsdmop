
# Monitor Spring Boot Application Performance with Elastic APM Java Agent


Under the deploymentConfig, spec.spec, add the following:
```yaml
      #### Shared volume and init container ###
      volumes: 
      - name: elastic-apm-agent 
        emptyDir: {} 
      initContainers: 
      - name: elastic-java-agent 
        image: docker.elastic.co/observability/apm-agent-java:1.12.0 
        volumeMounts: 
        - mountPath: /elastic/apm/agent 
          name: elastic-apm-agent 
        command: ['cp', '-v', '/usr/agent/elastic-apm-agent.jar', '/elastic/apm/agent']
      ##########################################
```

To the volumeMounts, mount a path for the Elastic Java APM Agent:
```yaml
        volumeMounts: 
        - mountPath: /elastic/apm/agent 
          name: elastic-apm-agent 
```	  
To the env vars set the following, note that the token should be stored in the secret within the project.
```yaml
        env: 
        - name: ELASTIC_APM_SERVER_URL 
          value: "http://apm-server-apm-http:8200" 
        - name: ELASTIC_APM_SERVICE_NAME 
          value: "petclinic" 
        - name: ELASTIC_APM_APPLICATION_PACKAGES 
          value: "org.springframework.samples.example" #app class here
        - name: ELASTIC_APM_ENVIRONMENT 
          value: test 
        - name: ELASTIC_APM_LOG_LEVEL 
          value: DEBUG 
        - name: ELASTIC_APM_SECRET_TOKEN 
          valueFrom: 
            secretKeyRef: 
              name: apm-server-apm-token 
              key: secret-token 
        - name: JAVA_TOOL_OPTIONS 
          value: -javaagent:/elastic/apm/agent/elastic-apm-agent.jar
```

To the Environment, add the following env vars:

We have now managed to monitor our Java application with Elastic APM without having to modify our application code, or its packaging, or its image.

Here is a complete deploymentConfg example, note that the initContainer config exists under ```spec.spec.initContainers```:


```yaml

apiVersion: apps/v1 
kind: Deployment 
metadata: 
  name: petclinic 
  namespace: default 
  labels: 
    app: petclinic 
    service: petclinic 
spec: 
  replicas: 1 
  selector: 
    matchLabels: 
      app: petclinic 
  template: 
    metadata: 
      labels: 
        app: petclinic 
        service: petclinic 
    spec: 
      dnsPolicy: ClusterFirstWithHostNet 
      ###################### Shared volume and init container ##########################
      volumes: 
      - name: elastic-apm-agent 
        emptyDir: {} 
      initContainers: 
      - name: elastic-java-agent 
        image: docker.elastic.co/observability/apm-agent-java:1.12.0 
        volumeMounts: 
        - mountPath: /elastic/apm/agent 
          name: elastic-apm-agent 
        command: ['cp', '-v', '/usr/agent/elastic-apm-agent.jar', '/elastic/apm/agent']
      ##################################################################################      
      containers: 
      - name: petclinic 
        image: eyalkoren/pet-clinic:without-agent
      ######################### Volume path and agent config ###########################
        volumeMounts: 
        - mountPath: /elastic/apm/agent 
          name: elastic-apm-agent 
        env: 
        - name: ELASTIC_APM_SERVER_URL 
          value: "http://apm-server-apm-http:8200" 
        - name: ELASTIC_APM_SERVICE_NAME 
          value: "petclinic" 
        - name: ELASTIC_APM_APPLICATION_PACKAGES 
          value: "org.springframework.samples.petclinic" 
        - name: ELASTIC_APM_ENVIRONMENT 
          value: test 
        - name: ELASTIC_APM_LOG_LEVEL 
          value: DEBUG 
        - name: ELASTIC_APM_SECRET_TOKEN 
          valueFrom: 
            secretKeyRef: 
              name: apm-server-apm-token 
              key: secret-token 
        - name: JAVA_TOOL_OPTIONS 
          value: -javaagent:/elastic/apm/agent/elastic-apm-agent.jar
      ##################################################################################

```
			



