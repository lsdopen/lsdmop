
#!/bin/bash

# Generator for Space onboarding for a Team - also sets up some basic alerts, security, dashboards, and an Email Connector
# Version 1.1.b.230224.1
#
# Usage: ./genspacealert.sh <teamname> <alert_destination_email> <user> <password> <eshostname> <kbhostname> "vx" "opseteam1 opesteam2 opsteam3"
# opsteams must be double quoted, pass NOOPS as the valur to apply no opsteams

# Eg: 

#TODO:
# 1) Implement usage output when no cmd line args
# 2) Combine gen and del scripts into one where selection can be made via a cmd --mode param
# 3) Handle case when there are multiple connectors, not just an EMAIL type connector
# 4) ...
# x) ...
# ?) TBD: This would be much better in Python - only considered the real edge-cases and complexity when working on it



GLOBIGNORE="*"

team=${1}
email=${2}
esusername=${3}
espassword=${4}
eshostname=${5}
kbhostname=${6}
version=${7}
opsteams=${8}
enabled=${9}

echo $team
echo $email
echo $version
echo $opsteams
echo $enabled

echo $enabled
if [[ $enabled == 'NO' ]]
then
  echo "Skipping Alert Generation due to input parameter"
  exit 0
fi

if [[ $email == '' ]]
then
  echo "Please specify email"
  exit 2
fi

if [[ $version == '' ]]
then
  echo "Please specify version for alerts (should be current + 1)"
  exit 2
fi

if [[ $opsteams == '' ]]
then 
  opsteams='NOOPS'
fi



#exit 0

if [[ $opsteams != 'NOOPS' ]]
# then
#   echo $opsteams "is not NONE"
# else
#   echo $opsteams "is NONE"
# fi
# exit 0



then

  for opsteam in $opsteams; do for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "tags": [
      "logs",
      "'${env,,}'",
      "ootb",
      "'${version,,}'"
    ],
    "name": "'${env}' '${team}' '${opsteam}'  LogLevel \"Error\" '${version,,}'",
    "enabled": false,
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "timeSize": 5,
      "timeUnit": "m",
      "logView": {
        "logViewId": "default",
        "type": "log-view-reference"
      },      
      "count": {
        "value": 1,
        "comparator": "more than or equals"
      },
      "criteria": [
        {
          "field": "kubernetes.labels.opsteam",
          "comparator": "equals",
          "value": "'${opsteam}'"
        },
        {
          "field": "kubernetes.labels.team",
          "comparator": "equals",
          "value": "'${team}'"
        },
        {
          "field": "kubernetes.labels.env",
          "comparator": "equals",
          "value": "'${env,,}'"
        },
        {
          "field": "log.level.keyword",
          "comparator": "equals",
          "value": "ERROR"
        },
        {
          "field": "message",
          "comparator": "does not match phrase",
          "value": "HealthCheckName"
        }
      ],
      "groupBy": [
        "kubernetes.namespace",
        "kubernetes.container.name"
      ]
    },
    "rule_type_id": "logs.alert.document.count",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "logs.threshold.fired",
        "id": "default-email",
        "params": {
          "message": "{{^context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}}{{context.matchingDocuments}} log entries have matched the following conditions: {{context.conditions}}{{/context.isRatio}}{{#context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}} Ratio of the count of log entries matching {{context.numeratorConditions}} to the count of log entries matching {{context.denominatorConditions}} was {{context.ratio}}{{/context.isRatio}}\n\n---\n---\n[View Occurrences](<{{kibanaBaseUrl}}/s/{{spaceId}}/app/discover#/?_a=(columns:!(kubernetes.namespace,kubernetes.container.name,message),filters:!(),grid:(columns:(kubernetes.container.name:(width:220),kubernetes.namespace:(width:155))),index:'\''018cd764-6956-4572-8f0b-6aa2963b5ad3'\'',interval:auto,query:(language:kuery,query:'\''kubernetes.labels.env%20:%22{{params.criteria.2.value}}%22%20AND%20kubernetes.labels.opsteam%20:%22{{params.criteria.0.value}}%22%20AND%20kubernetes.labels.team%20:%22{{params.criteria.1.value}}%22%20AND%20log.level.keyword:%22{{params.criteria.3.value}}%22%20AND%20NOT%20message:%22{{params.criteria.4.value}}%22'\''),sort:!(!('\''@timestamp'\'',desc)))&_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:'\''{{context.timestamp}}||-15m'\'',to:'\''{{context.timestamp}}'\''))>)\n\n\n---\n---\n{{.}}",
          "to": [
            "'${email}'"
          ],
          "subject": "{{rule.name}} - {{alert.id}}"
        }
      }
    ]
  }
  ';
  done; done;


  for opsteam in ${opsteams}; do for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "tags": [
      "inventory",
      "'${env,,}'",
      "ootb",
      "'${version,,}'"
    ],
    "name": "'$env' '$team' '$opsteam' Metrics CPU Limit Percentage Exceeded '${version,,}'",
    "enabled": false,
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "criteria": [
        {
          "comparator": ">",
          "timeSize": 10,
          "metric": "kubernetes.container.cpu.usage.limit.pct",
          "aggType": "avg",
          "threshold": [
            0.9
          ],
          "warningThreshold": [
            0.85
          ],
          "timeUnit": "m",
          "warningComparator": ">"
        }
      ],
      "sourceId": "default",
      "alertOnNoData": true,
      "alertOnGroupDisappear": true,
      "filterQueryText": "labels.opsteam:\"'$opsteam'\" AND labels.team:\"'$team'\" AND kubernetes.labels.env:\"'${env,,}'\" ",
      "filterQuery": "{\"bool\":{\"filter\":[{\"bool\":{\"should\":[{\"match_phrase\":{\"labels.team\":\"'$team'\"}}],\"minimum_should_match\":1}},{\"bool\":{\"should\":[{\"match_phrase\":{\"kubernetes.labels.env\":\"'${env,,}'\"}}],\"minimum_should_match\":1}},{\"bool\":{\"should\":[{\"match_phrase\":{\"labels.opsteam\":\"'$opsteam'\"}}],\"minimum_should_match\":1}}]}}",
      "groupBy": [
        "kubernetes.namespace",
        "kubernetes.container.name"
      ]
    },
    "rule_type_id": "metrics.alert.threshold",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "metrics.threshold.fired",
        "id": "default-email",
        "params": {
          "subject": "{{alertName}} has ocurred",
          "to": [
            "'${email}'"
          ],
          "message": "{{alertName}} - {{context.group}} is in a state of {{context.alertState}}\n\nReason:\n{{context.reason}}\n\n----------\n\n{{.}}\n"
        }
      }
    ]
  }';
  done; done;

  for opsteam in ${opsteams}; do for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "tags": [
      "inventory",
      "'${env,,}'",
      "ootb",
      "'${version,,}'"
    ],
    "name": "'$env' '$team' '$opsteam' Metrics MEM Limit Percentage Exceeded '${version,,}'",
    "enabled": false,
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "criteria": [
        {
          "comparator": ">",
          "timeSize": 10,
          "metric": "kubernetes.container.memory.usage.limit.pct",
          "aggType": "avg",
          "threshold": [
            0.9
          ],
          "warningThreshold": [
            0.85
          ],
          "timeUnit": "m",
          "warningComparator": ">"
        }
      ],
      "sourceId": "default",
      "alertOnNoData": true,
      "alertOnGroupDisappear": true,
      "filterQueryText": "labels.opsteam:\"'$opsteam'\" AND labels.team:\"'$team'\" AND kubernetes.labels.env:\"'${env,,}'\" ",
      "filterQuery": "{\"bool\":{\"filter\":[{\"bool\":{\"should\":[{\"match_phrase\":{\"labels.team\":\"'$team'\"}}],\"minimum_should_match\":1}},{\"bool\":{\"should\":[{\"match_phrase\":{\"kubernetes.labels.env\":\"'${env,,}'\"}}],\"minimum_should_match\":1}},{\"bool\":{\"should\":[{\"match_phrase\":{\"labels.opsteam\":\"'$opsteam'\"}}],\"minimum_should_match\":1}}]}}",
      "groupBy": [
        "kubernetes.namespace",
        "kubernetes.container.name"
      ]
    },
    "rule_type_id": "metrics.alert.threshold",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "metrics.threshold.fired",
        "id": "default-email",
        "params": {
          "subject": "{{alertName}} has ocurred",
          "to": [
            "'${email}'"
          ],
          "message": "{{alertName}} - {{context.group}} is in a state of {{context.alertState}}\n\nReason:\n{{context.reason}}\n\n----------\n\n{{.}}\n"
        }
      }
    ]
  }';
  done; done;  

  for opsteam in ${opsteams}; do for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "tags": [
      "apm",
      "ootb",
      "'${env,,}'",
      "anomaly",
      "'${version,,}'"
    ],
    "name": "'$env' '$team' '$opsteam' Anomaly Detection - Critical '${version,,}'",
    "enabled": false,
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "windowSize": 30,
      "windowUnit": "m",
      "anomalySeverityType": "critical",
      "environment": "Production"
    },
    "rule_type_id": "apm.anomaly",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "threshold_met",
        "id": "default-email",
        "params": {
          "subject": "{{rule.name}} - {{alert.id}} - {{context.serviceName}}",
          "to": [
            "'${email}'"
          ],
          "message": "{{alertName}} alert is firing because of the following conditions:\n\n- Service name: {{context.serviceName}}\n- Type: {{context.transactionType}}\n- Environment: {{context.environment}}\n- Severity threshold: {{context.threshold}}\n- Severity value: {{context.triggerValue}}\n{{context.viewInAppUrl}}\n---\n{{.}}\n"
        }
      }
    ]
  }';
  done; done;

  for opsteam in ${opsteams}; do for env in PRD DEV TST; do for reason in BackOff BuildFailed FailedCreate FailedMount FailedScheduling Killing ResolutionFailed Unhealthy Warning;
  do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
      "consumer": "alerts",
      "tags": [
        "ocp", "'${env,,}'", "ootb",  "'${version,,}'"
      ],
      "name": "'$env' '$team' '$opsteam' OCP Event '$reason' '${version,,}'",
      "enabled": false,
      "throttle": null,
      "schedule": {
        "interval": "1m"
      },
      "params": {
        "searchConfiguration": {
          "query": {
            "query": "kubernetes.event.reason : \"'$reason'\" AND kubernetes.labels.team :\"'$team'\" AND kubernetes.labels.opsteam :\"'$opsteam'\" AND kubernetes.labels.env :\"'${env,,}'\"",
            "language": "kuery"
          },
          "index": "49dbc3da-615e-477f-ae02-c72a79c074de"
        },
        "searchType": "searchSource",
        "timeWindowSize": 30,
        "timeWindowUnit": "m",
        "threshold": [
          0
        ],
        "thresholdComparator": ">",
        "size": 100,
        "excludeHitsFromPreviousRun": true
      },
      "rule_type_id": ".es-query",
      "notify_when": "onActionGroupChange",
      "actions": [
          {
            "group": "query matched",
            "id": "default-email",
            "params": {
              "message": "Elasticsearch query alert {{alertName}} is active:\n\n- Value: {{context.value}}\n- Conditions Met: {{context.conditions}} over {{params.timeWindowSize}}{{params.timeWindowUnit}}\n- Timestamp: {{context.date}}\n- Link: {{context.link}}\n\n- metas\n{{#context.hits}}\n  - name: {{_source.kubernetes.event.metadata.name}} \n  - namespace: {{_source.kubernetes.event.metadata.namespace}} \n{{/context.hits}}\n\n===========================\n\n\n- Full Context\n{{context.hits}}\n{{.}}",
              "to": [
                "'${email}'"
              ],
              "subject": "{{alertName}} has ocurred"
            }
          }      
      ]
    }

  ';
  done; done; done;


  for opsteam in ${opsteams}; do for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "enabled": false,
    "name": "'${env}' '${team}' '${opsteam}' UPTIME '${version,,}'",
    "tags": [
      "Uptime",
      "custom",
      "'${version,,}'",
      "ootb",
      "'${env,,}'"
    ],
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "availability": {
        "range": 30,
        "rangeUnit": "d",
        "threshold": "99"
      },
      "filters": {
        "monitor.type": [],
        "observer.geo.name": [],
        "tags": [],
        "url.port": []
      },
      "numTimes": 5,
      "search": "kubernetes.labels.opsteam :\"'${opsteam}'\" and kubernetes.labels.team :\"'${team}'\" and kubernetes.labels.env : \"'${env,,}'\"",
      "shouldCheckAvailability": true,
      "shouldCheckStatus": true,
      "timerangeCount": 15,
      "timerangeUnit": "m"
    },
    "rule_type_id": "xpack.uptime.alerts.monitorStatus",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "xpack.uptime.alerts.actionGroups.monitorStatus",
        "id": "default-email",
        "params": {
          "message": "Monitor {{context.monitorName}} with url {{{context.monitorUrl}}} from {{context.observerLocation}} {{{context.statusMessage}}} The latest error message is {{{context.latestErrorMessage}}}",
          "subject": "{{rule.name}} - {{alert.id}} - {{context.monitorName}} - UPTIME - {{#context.hits}}{{_source.kubernetes.labels.env}}/{{/context.hits}} - {{#context.hits}}{{_source.kubernetes.container.name}}/{{/context.hits}}",
          "to": [
            "'${email}'"
          ]
        }
      }
    ]
  }';
  done; done;



  for env in PRD; do curl -k -XPUT "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/ml/anomaly_detectors/apm-production-${team,,}-apm_tx_metrics?pretty"  -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "groups": [
      "apm"
    ],
    "custom_settings": {
      "managed": true,
      "job_tags": {
        "environment": "Production"
      },
      "custom_urls": []
    },
    "description": "Detects anomalies in transaction latency, throughput and error percentage for metric data.",
    "analysis_config": {
      "bucket_span": "15m",
      "summary_count_field_name": "doc_count",
      "detectors": [
        {
          "detector_description": "high latency by transaction type for an APM service",
          "function": "high_mean",
          "field_name": "transaction_latency",
          "by_field_name": "transaction.type",
          "partition_field_name": "service.name",
          "detector_index": 0
        },
        {
          "detector_description": "transaction throughput for an APM service",
          "function": "mean",
          "field_name": "transaction_throughput",
          "by_field_name": "transaction.type",
          "partition_field_name": "service.name",
          "detector_index": 1
        },
        {
          "detector_description": "failed transaction rate for an APM service",
          "function": "high_mean",
          "field_name": "failed_transaction_rate",
          "by_field_name": "transaction.type",
          "partition_field_name": "service.name",
          "detector_index": 2
        }
      ],
      "influencers": [
        "transaction.type",
        "service.name"
      ],
      "model_prune_window": "30d"
  },
    "data_description": {
      "time_field": "timestamp",
      "time_format": "epoch_ms"
    },
    "analysis_limits": {
      "model_memory_limit": "23mb",
      "categorization_examples_limit": 4
  },
    "model_plot_config": {
      "enabled": true,
      "annotations_enabled": true
    },
    "results_index_name": "custom-apm",
    "datafeed_config": {
      "datafeed_id": "datafeed-apm-production-'${team,,}'-apm_tx_metrics",
      "job_id": "apm-production-'${team,,}'-apm_tx_metrics",
      "query_delay": "93346ms",
      "chunking_config": {
        "mode": "off"
      },
      "indices_options": {
        "expand_wildcards": [
          "open"
        ],
        "ignore_unavailable": true,
        "allow_no_indices": true,
        "ignore_throttled": true
      },
      "query": {
        "bool": {
          "filter": [
            {
              "term": {
                "processor.event": "metric"
              }
            },
            {
              "term": {
                "metricset.name": "transaction"
              }
            },
            {
              "term": {
                "service.environment": "Production"
              }
            },
            {
              "term": {
                "labels.team": "'${team}'"
              }
            }
          ]
        }
      },
      "indices": [
        "metrics-apm*",
        "apm-*"
      ],
      "aggregations": {
        "buckets": {
          "composite": {
            "size": 5000,
            "sources": [
              {
                "date": {
                  "date_histogram": {
                    "field": "@timestamp",
                    "fixed_interval": "60s"
                  }
                }
              },
              {
                "transaction.type": {
                  "terms": {
                    "field": "transaction.type"
                  }
                }
              },
              {
                "service.name": {
                  "terms": {
                    "field": "service.name"
                  }
                }
              }
            ]
          },
          "aggs": {
            "@timestamp": {
              "max": {
                "field": "@timestamp"
              }
            },
            "transaction_throughput": {
              "rate": {
                "unit": "minute"
              }
            },
            "transaction_latency": {
              "avg": {
                "field": "transaction.duration.histogram"
              }
            },
            "error_count": {
              "filter": {
                "term": {
                  "event.outcome": "failure"
                }
              },
              "aggs": {
                "actual_error_count": {
                  "value_count": {
                    "field": "event.outcome"
                  }
                }
              }
            },
            "success_count": {
              "filter": {
                "term": {
                  "event.outcome": "success"
                }
              }
            },
            "failed_transaction_rate": {
              "bucket_script": {
                "buckets_path": {
                  "failure_count": "error_count>_count",
                  "success_count": "success_count>_count"
                },
                "script": "if ((params.failure_count + params.success_count)==0){return 0;}else{return 100 * (params.failure_count/(params.failure_count + params.success_count));}"
              }
            }
          }
        }
      },
      "scroll_size": 1000,
      "delayed_data_check_config": {
        "enabled": true
      }
    }
  }';
  done;  
##############################################################################################################
else
  for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "tags": [
      "logs",
      "'${env,,}'",
      "ootb",
      "'${version,,}'"
    ],
    "name": "'${env}' '${team}' LogLevel \"Error\" '${version,,}'",
    "enabled": false,
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "timeSize": 5,
      "timeUnit": "m",
      "logView": {
        "logViewId": "default",
        "type": "log-view-reference"
      },      
      "count": {
        "value": 1,
        "comparator": "more than or equals"
      },
      "criteria": [
        {
          "field": "kubernetes.labels.team",
          "comparator": "equals",
          "value": "'${team}'"
        },
        {
          "field": "kubernetes.labels.env",
          "comparator": "equals",
          "value": "'${env,,}'"
        },
        {
          "field": "log.level.keyword",
          "comparator": "equals",
          "value": "ERROR"
        },
        {
          "field": "message",
          "comparator": "does not match phrase",
          "value": "HealthCheckName"
        }
      ],
      "groupBy": [
        "kubernetes.namespace",
        "kubernetes.container.name"
      ]
    },
    "rule_type_id": "logs.alert.document.count",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "logs.threshold.fired",
        "id": "default-email",
        "params": {
          "message": "{{^context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}}{{context.matchingDocuments}} log entries have matched the following conditions: {{context.conditions}}{{/context.isRatio}}{{#context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}} Ratio of the count of log entries matching {{context.numeratorConditions}} to the count of log entries matching {{context.denominatorConditions}} was {{context.ratio}}{{/context.isRatio}}\n\n---\n---\n[View Occurrences](<{{kibanaBaseUrl}}/s/{{spaceId}}/app/discover#/?_a=(columns:!(kubernetes.namespace,kubernetes.container.name,message),filters:!(),grid:(columns:(kubernetes.container.name:(width:220),kubernetes.namespace:(width:155))),index:'\''018cd764-6956-4572-8f0b-6aa2963b5ad3'\'',interval:auto,query:(language:kuery,query:'\''kubernetes.labels.env%20:%22{{params.criteria.1.value}}%22%20AND%20kubernetes.labels.team%20:%22{{params.criteria.0.value}}%22%20AND%20log.level.keyword:%22{{params.criteria.2.value}}%22%20AND%20NOT%20message:%22{{params.criteria.3.value}}%22'\''),sort:!(!('\''@timestamp'\'',desc)))&_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:'\''{{context.timestamp}}||-15m'\'',to:'\''{{context.timestamp}}'\''))>)\n\n\n---\n---\n{{.}}",
          "to": [
            "'${email}'"
          ],
          "subject": "{{rule.name}} - {{alert.id}}"
        }
      }
    ]
  }
  ';
  done; 


  for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "tags": [
      "inventory",
      "'${env,,}'",
      "ootb",
      "'${version,,}'"
    ],
    "name": "'$env' '$team' Metrics CPU Limit Percentage Exceeded '${version,,}'",
    "enabled": false,
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "criteria": [
        {
          "comparator": ">",
          "timeSize": 10,
          "metric": "kubernetes.container.cpu.usage.limit.pct",
          "aggType": "avg",
          "threshold": [
            0.9
          ],
          "warningThreshold": [
            0.85
          ],
          "timeUnit": "m",
          "warningComparator": ">"
        }
      ],
      "sourceId": "default",
      "alertOnNoData": true,
      "alertOnGroupDisappear": true,
      "filterQueryText": "labels.team:\"'$team'\" AND kubernetes.labels.env:\"'${env,,}'\" ",
      "filterQuery": "{\"bool\":{\"filter\":[{\"bool\":{\"should\":[{\"match_phrase\":{\"labels.team\":\"'$team'\"}}],\"minimum_should_match\":1}},{\"bool\":{\"should\":[{\"match_phrase\":{\"kubernetes.labels.env\":\"'${env,,}'\"}}],\"minimum_should_match\":1}}]}}",
      "groupBy": [
        "kubernetes.namespace",
        "kubernetes.container.name"
      ]
    },
    "rule_type_id": "metrics.alert.threshold",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "metrics.threshold.fired",
        "id": "default-email",
        "params": {
          "subject": "{{alertName}} has ocurred",
          "to": [
            "'${email}'"
          ],
          "message": "{{alertName}} - {{context.group}} is in a state of {{context.alertState}}\n\nReason:\n{{context.reason}}\n\n----------\n\n{{.}}\n"
        }
      }
    ]
  }';
  done;

    for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "tags": [
      "inventory",
      "'${env,,}'",
      "ootb",
      "'${version,,}'"
    ],
    "name": "'$env' '$team' Metrics MEM Limit Percentage Exceeded '${version,,}'",
    "enabled": false,
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "criteria": [
        {
          "comparator": ">",
          "timeSize": 10,
          "metric": "kubernetes.container.memory.usage.limit.pct",
          "aggType": "avg",
          "threshold": [
            0.9
          ],
          "warningThreshold": [
            0.85
          ],
          "timeUnit": "m",
          "warningComparator": ">"
        }
      ],
      "sourceId": "default",
      "alertOnNoData": true,
      "alertOnGroupDisappear": true,
      "filterQueryText": "labels.team:\"'$team'\" AND kubernetes.labels.env:\"'${env,,}'\" ",
      "filterQuery": "{\"bool\":{\"filter\":[{\"bool\":{\"should\":[{\"match_phrase\":{\"labels.team\":\"'$team'\"}}],\"minimum_should_match\":1}},{\"bool\":{\"should\":[{\"match_phrase\":{\"kubernetes.labels.env\":\"'${env,,}'\"}}],\"minimum_should_match\":1}}]}}",
      "groupBy": [
        "kubernetes.namespace",
        "kubernetes.container.name"
      ]
    },
    "rule_type_id": "metrics.alert.threshold",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "metrics.threshold.fired",
        "id": "default-email",
        "params": {
          "subject": "{{alertName}} has ocurred",
          "to": [
            "'${email}'"
          ],
          "message": "{{alertName}} - {{context.group}} is in a state of {{context.alertState}}\n\nReason:\n{{context.reason}}\n\n----------\n\n{{.}}\n"
        }
      }
    ]
  }';
  done;

  for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "tags": [
      "apm",
      "ootb",
      "'${env,,}'",
      "anomaly",
      "'${version,,}'"
    ],
    "name": "'$env' '$team' Anomaly Detection - Critical '${version,,}'",
    "enabled": false,
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "windowSize": 30,
      "windowUnit": "m",
      "anomalySeverityType": "critical",
      "environment": "Production"
    },
    "rule_type_id": "apm.anomaly",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "threshold_met",
        "id": "default-email",
        "params": {
          "subject": "{{rule.name}} - {{alert.id}} - {{context.serviceName}}",
          "to": [
            "'${email}'"
          ],
          "message": "{{alertName}} alert is firing because of the following conditions:\n\n- Service name: {{context.serviceName}}\n- Type: {{context.transactionType}}\n- Environment: {{context.environment}}\n- Severity threshold: {{context.threshold}}\n- Severity value: {{context.triggerValue}}\n{{context.viewInAppUrl}}\n---\n{{.}}\n"
        }
      }
    ]
  }';
  done;

  for env in PRD DEV TST; do for reason in BackOff BuildFailed FailedCreate FailedMount FailedScheduling Killing ResolutionFailed Unhealthy Warning; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
      "consumer": "alerts",
      "tags": [
        "ocp", "'${env,,}'", "ootb",  "'${version,,}'"
      ],
      "name": "'$env' '$team' OCP Event '$reason' '${version,,}'",
      "enabled": false,
      "throttle": null,
      "schedule": {
        "interval": "1m"
      },
      "params": {
        "searchConfiguration": {
          "query": {
            "query": "kubernetes.event.reason : \"'$reason'\" AND kubernetes.labels.team :\"'$team'\" AND kubernetes.labels.env :\"'${env,,}'\"",
            "language": "kuery"
          },
          "index": "49dbc3da-615e-477f-ae02-c72a79c074de"
        },
        "searchType": "searchSource",
        "timeWindowSize": 30,
        "timeWindowUnit": "m",
        "threshold": [
          0
        ],
        "thresholdComparator": ">",
        "size": 100,
        "excludeHitsFromPreviousRun": true
      },
      "rule_type_id": ".es-query",
      "notify_when": "onActionGroupChange",
      "actions": [
          {
            "group": "query matched",
            "id": "default-email",
            "params": {
              "message": "Elasticsearch query alert {{alertName}} is active:\n\n- Value: {{context.value}}\n- Conditions Met: {{context.conditions}} over {{params.timeWindowSize}}{{params.timeWindowUnit}}\n- Timestamp: {{context.date}}\n- Link: {{context.link}}\n\n- metas\n{{#context.hits}}\n  - name: {{_source.kubernetes.event.metadata.name}} \n  - namespace: {{_source.kubernetes.event.metadata.namespace}} \n{{/context.hits}}\n\n===========================\n\n\n- Full Context\n{{context.hits}}\n{{.}}",
              "to": [
                "'${email}'"
              ],
              "subject": "{{alertName}} has ocurred"
            }
          }      
      ]
    }

  ';
  done; done;


  for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "consumer": "alerts",
    "enabled": false,
    "name": "'${env}' '${team}' UPTIME '${version,,}'",
    "tags": [
      "Uptime",
      "custom",
      "'${version,,}'",
      "ootb",
      "'${env,,}'"
    ],
    "throttle": null,
    "schedule": {
      "interval": "1m"
    },
    "params": {
      "availability": {
        "range": 30,
        "rangeUnit": "d",
        "threshold": "99"
      },
      "filters": {
        "monitor.type": [],
        "observer.geo.name": [],
        "tags": [],
        "url.port": []
      },
      "numTimes": 5,
      "search": "kubernetes.labels.team :\"'${team}'\" and kubernetes.labels.env : \"'${env,,}'\"",
      "shouldCheckAvailability": true,
      "shouldCheckStatus": true,
      "timerangeCount": 15,
      "timerangeUnit": "m"
    },
    "rule_type_id": "xpack.uptime.alerts.monitorStatus",
    "notify_when": "onActionGroupChange",
    "actions": [
      {
        "group": "xpack.uptime.alerts.actionGroups.monitorStatus",
        "id": "default-email",
        "params": {
          "message": "Monitor {{context.monitorName}} with url {{{context.monitorUrl}}} from {{context.observerLocation}} {{{context.statusMessage}}} The latest error message is {{{context.latestErrorMessage}}}",
          "subject": "{{rule.name}} - {{alert.id}} - {{context.monitorName}} - UPTIME - {{#context.hits}}{{_source.kubernetes.labels.env}}/{{/context.hits}} - {{#context.hits}}{{_source.kubernetes.container.name}}/{{/context.hits}}",
          "to": [
            "'${email}'"
          ]
        }
      }
    ]
  }';
  done; 



  for env in PRD; do curl -k -XPUT "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/ml/anomaly_detectors/apm-production-${team,,}-apm_tx_metrics?pretty"  -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
  {
    "groups": [
      "apm"
    ],
    "custom_settings": {
      "managed": true,
      "job_tags": {
        "environment": "Production"
      },
      "custom_urls": []
    },
    "description": "Detects anomalies in transaction latency, throughput and error percentage for metric data.",
    "analysis_config": {
      "bucket_span": "15m",
      "summary_count_field_name": "doc_count",
      "detectors": [
        {
          "detector_description": "high latency by transaction type for an APM service",
          "function": "high_mean",
          "field_name": "transaction_latency",
          "by_field_name": "transaction.type",
          "partition_field_name": "service.name",
          "detector_index": 0
        },
        {
          "detector_description": "transaction throughput for an APM service",
          "function": "mean",
          "field_name": "transaction_throughput",
          "by_field_name": "transaction.type",
          "partition_field_name": "service.name",
          "detector_index": 1
        },
        {
          "detector_description": "failed transaction rate for an APM service",
          "function": "high_mean",
          "field_name": "failed_transaction_rate",
          "by_field_name": "transaction.type",
          "partition_field_name": "service.name",
          "detector_index": 2
        }
      ],
      "influencers": [
        "transaction.type",
        "service.name"
      ],
      "model_prune_window": "30d"
  },
    "data_description": {
      "time_field": "timestamp",
      "time_format": "epoch_ms"
    },
    "analysis_limits": {
      "model_memory_limit": "23mb",
      "categorization_examples_limit": 4
  },
    "model_plot_config": {
      "enabled": true,
      "annotations_enabled": true
    },
    "results_index_name": "custom-apm",
    "datafeed_config": {
      "datafeed_id": "datafeed-apm-production-'${team,,}'-apm_tx_metrics",
      "job_id": "apm-production-'${team,,}'-apm_tx_metrics",
      "query_delay": "93346ms",
      "chunking_config": {
        "mode": "off"
      },
      "indices_options": {
        "expand_wildcards": [
          "open"
        ],
        "ignore_unavailable": true,
        "allow_no_indices": true,
        "ignore_throttled": true
      },
      "query": {
        "bool": {
          "filter": [
            {
              "term": {
                "processor.event": "metric"
              }
            },
            {
              "term": {
                "metricset.name": "transaction"
              }
            },
            {
              "term": {
                "service.environment": "Production"
              }
            },
            {
              "term": {
                "labels.team": "'${team}'"
              }
            }
          ]
        }
      },
      "indices": [
        "metrics-apm*",
        "apm-*"
      ],
      "aggregations": {
        "buckets": {
          "composite": {
            "size": 5000,
            "sources": [
              {
                "date": {
                  "date_histogram": {
                    "field": "@timestamp",
                    "fixed_interval": "60s"
                  }
                }
              },
              {
                "transaction.type": {
                  "terms": {
                    "field": "transaction.type"
                  }
                }
              },
              {
                "service.name": {
                  "terms": {
                    "field": "service.name"
                  }
                }
              }
            ]
          },
          "aggs": {
            "@timestamp": {
              "max": {
                "field": "@timestamp"
              }
            },
            "transaction_throughput": {
              "rate": {
                "unit": "minute"
              }
            },
            "transaction_latency": {
              "avg": {
                "field": "transaction.duration.histogram"
              }
            },
            "error_count": {
              "filter": {
                "term": {
                  "event.outcome": "failure"
                }
              },
              "aggs": {
                "actual_error_count": {
                  "value_count": {
                    "field": "event.outcome"
                  }
                }
              }
            },
            "success_count": {
              "filter": {
                "term": {
                  "event.outcome": "success"
                }
              }
            },
            "failed_transaction_rate": {
              "bucket_script": {
                "buckets_path": {
                  "failure_count": "error_count>_count",
                  "success_count": "success_count>_count"
                },
                "script": "if ((params.failure_count + params.success_count)==0){return 0;}else{return 100 * (params.failure_count/(params.failure_count + params.success_count));}"
              }
            }
          }
        }
      },
      "scroll_size": 1000,
      "delayed_data_check_config": {
        "enabled": true
      }
    }
  }';
  done;

fi




















#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################
#################################################################

# for opsteam in ${opsteams}; do for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
# {
#   "consumer": "alerts",
#   "tags": [
#     "logs",
#     "'${env,,}'",
#     "ootb",
#      "'${version,,}'"
#   ],
#   "name": "'${team}' '${env}' Logs \"Error\" '${version,,}'",
#   "enabled": false,
#   "throttle": null,
#   "schedule": {
#     "interval": "1m"
#   },
#   "params": {
#     "timeSize": 5,
#     "timeUnit": "m",
#     "count": {
#       "value": 1,
#       "comparator": "more than or equals"
#     },
#     "criteria": [
#       {
#         "field": "kubernetes.labels.team",
#         "comparator": "equals",
#         "value": "'${team}'"
#       },
#       {
#         "field": "kubernetes.labels.opsteam",
#         "comparator": "equals",
#         "value": "'${opsteam,,}'"
#       },
#       {
#         "field": "kubernetes.labels.env",
#         "comparator": "equals",
#         "value": "'${env,,}'"
#       },
#       {
#         "field": "message",
#         "comparator": "matches phrase",
#         "value": "error"
#       }
#     ],
#     "groupBy": [
#       "kubernetes.namespace",
#       "kubernetes.container.name"
#     ]
#   },
#   "rule_type_id": "logs.alert.document.count",
#   "notify_when": "onActionGroupChange",
#   "actions": [
#     {
#       "group": "logs.threshold.fired",
#       "id": "default-email",
#       "params": {
#         "message": "{{^context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}}{{context.matchingDocuments}} log entries have matched the following conditions: {{context.conditions}}{{/context.isRatio}}{{#context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}} Ratio of the count of log entries matching {{context.numeratorConditions}} to the count of log entries matching {{context.denominatorConditions}} was {{context.ratio}}{{/context.isRatio}}\n\n---\n---\n[View Occurrences](<{{kibanaBaseUrl}}/s/{{spaceId}}/app/discover#/?_a=(columns:!(kubernetes.namespace,kubernetes.container.name,message),filters:!(),grid:(columns:(kubernetes.container.name:(width:220),kubernetes.namespace:(width:155))),index:'\''018cd764-6956-4572-8f0b-6aa2963b5ad3'\'',interval:auto,query:(language:kuery,query:'\''kubernetes.labels.env%20:%22{{params.criteria.1.value}}%22%20AND%20kubernetes.labels.team%20:%22{{params.criteria.0.value}}%22%20AND%20message:%22{{params.criteria.2.value}}%22'\''),sort:!(!('\''@timestamp'\'',desc)))&_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:'\''{{context.timestamp}}||-15m'\'',to:'\''{{context.timestamp}}'\''))>)\n\n\n---\n---\n{{.}}",
#         "to": [
#           "'${email}'"
#         ],
#         "subject": "{{rule.name}} - {{alert.id}}"
#       }
#     }
#   ]
# }
# ';
# done; done;


# for opsteam in ${opsteams}; do for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
# {
#   "consumer": "alerts",
#   "tags": [
#     "logs",
#     "'${env,,}'",
#     "ootb",
#      "'${version,,}'"
#   ],
#   "name": "'${team}' '${env}' Logs \"Unhandled Exception\" '${version,,}'",
#   "enabled": false,
#   "throttle": null,
#   "schedule": {
#     "interval": "1m"
#   },
#   "params": {
#     "timeSize": 5,
#     "timeUnit": "m",
#     "count": {
#       "value": 1,
#       "comparator": "more than or equals"
#     },
#     "criteria": [
#       {
#         "field": "kubernetes.labels.team",
#         "comparator": "equals",
#         "value": "'${team}'"
#       },
#       {
#         "field": "kubernetes.labels.team",
#         "comparator": "equals",
#         "value": "'${opsteam,,}'"
#       },
#       {
#         "field": "kubernetes.labels.env",
#         "comparator": "equals",
#         "value": "'${env,,}'"
#       },
#       {
#         "field": "message",
#         "comparator": "matches phrase",
#         "value": "unhandled exception"
#       }
#     ],
#     "groupBy": [
#       "kubernetes.namespace",
#       "kubernetes.container.name"
#     ]
#   },
#   "rule_type_id": "logs.alert.document.count",
#   "notify_when": "onActiveAlert",
#   "actions": [
#     {
#       "group": "logs.threshold.fired",
#       "id": "default-email",
#       "params": {
#         "message": "{{^context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}}{{context.matchingDocuments}} log entries have matched the following conditions: {{context.conditions}}{{/context.isRatio}}{{#context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}} Ratio of the count of log entries matching {{context.numeratorConditions}} to the count of log entries matching {{context.denominatorConditions}} was {{context.ratio}}{{/context.isRatio}}\n\n---\n---\n[View Occurrences](<{{kibanaBaseUrl}}/s/{{spaceId}}/app/discover#/?_a=(columns:!(kubernetes.namespace,kubernetes.container.name,message),filters:!(),grid:(columns:(kubernetes.container.name:(width:220),kubernetes.namespace:(width:155))),index:'\''018cd764-6956-4572-8f0b-6aa2963b5ad3'\'',interval:auto,query:(language:kuery,query:'\''kubernetes.labels.env%20:%22{{params.criteria.1.value}}%22%20AND%20kubernetes.labels.team%20:%22{{params.criteria.0.value}}%22%20AND%20message:%22{{params.criteria.2.value}}%22'\''),sort:!(!('\''@timestamp'\'',desc)))&_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:'\''{{context.timestamp}}||-15m'\'',to:'\''{{context.timestamp}}'\''))>)\n\n\n---\n---\n{{.}}",
#         "to": [
#           "'${email}'"
#         ],
#         "subject": "{{rule.name}} - {{alert.id}}"
#       }
#     }
#   ]
# }
# ';
# done; done;

# for opsteam in ${opsteams}; do for env in PRD DEV TST; do curl -k -XPOST "https://$esusername:$espassword@$kbhostname/s/${team,,}/api/alerting/rule" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
# {
#   "consumer": "alerts",
#   "tags": [
#     "logs",
#     "'${env,,}'",
#     "ootb",
#      "'${version,,}'"
#   ],
#   "name": "'${cluster}' '${team}' '${env}' Logs \"DbUpdateException\" '${version,,}'",
#   "enabled": false,
#   "throttle": null,
#   "schedule": {
#     "interval": "1m"
#   },
#   "params": {
#     "timeSize": 5,
#     "timeUnit": "m",
#     "count": {
#       "value": 1,
#       "comparator": "more than or equals"
#     },
#     "criteria": [
#       {
#         "field": "kubernetes.labels.team",
#         "comparator": "equals",
#         "value": "'${team}'"
#       },
#       {
#         "field": "kubernetes.labels.opsteam",
#         "comparator": "equals",
#         "value": "'${opsteam}'"
#       },
#       {
#         "field": "kubernetes.labels.env",
#         "comparator": "equals",
#         "value": "'${env,,}'"
#       },
#       {
#         "field": "message",
#         "comparator": "matches phrase",
#         "value": "DbUpdateException"
#       }
#     ],
#     "groupBy": [
#       "kubernetes.namespace",
#       "kubernetes.container.name"
#     ]
#   },
#   "rule_type_id": "logs.alert.document.count",
#   "notify_when": "onActionGroupChange",
#   "actions": [
#     {
#       "group": "logs.threshold.fired",
#       "id": "default-email",
#       "params": {
#         "message": "{{^context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}}{{context.matchingDocuments}} log entries have matched the following conditions: {{context.conditions}}{{/context.isRatio}}{{#context.isRatio}}{{#context.group}}{{context.group}} - {{/context.group}} Ratio of the count of log entries matching {{context.numeratorConditions}} to the count of log entries matching {{context.denominatorConditions}} was {{context.ratio}}{{/context.isRatio}}\n\n---\n---\n[View Occurrences](<{{kibanaBaseUrl}}/s/{{spaceId}}/app/discover#/?_a=(columns:!(kubernetes.namespace,kubernetes.container.name,message),filters:!(),grid:(columns:(kubernetes.container.name:(width:220),kubernetes.namespace:(width:155))),index:'\''018cd764-6956-4572-8f0b-6aa2963b5ad3'\'',interval:auto,query:(language:kuery,query:'\''kubernetes.labels.env%20:%22{{params.criteria.1.value}}%22%20AND%20kubernetes.labels.team%20:%22{{params.criteria.0.value}}%22%20AND%20message:%22{{params.criteria.2.value}}%22'\''),sort:!(!('\''@timestamp'\'',desc)))&_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:'\''{{context.timestamp}}||-15m'\'',to:'\''{{context.timestamp}}'\''))>)\n\n\n---\n---\n{{.}}",
#         "to": [
#           "'${email}'"
#         ],
#         "subject": "{{rule.name}} - {{alert.id}}"
#       }
#     }
#   ]
# }
# ';
# done; done