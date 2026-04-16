#!/bin/bash
helm install otel-collector open-telemetry/opentelemetry-collector -n lsdmopagent -f ./otel-nonp.yaml