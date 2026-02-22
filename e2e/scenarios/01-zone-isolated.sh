#!/usr/bin/env bash

IP_GLOBAL_A="$(pod_ip e2e-global-a workspace-system)"
IP_ISOLATED_B="$(pod_ip e2e-alpha-isolated-b ws-alpha)"
IP_PROJECT_A="$(pod_ip e2e-alpha-project-a ws-alpha)"

assert_allow "01 isolated→global (allow)" \
  e2e-alpha-isolated-a ws-alpha "${IP_GLOBAL_A}"

assert_deny "02 isolated→isolated same-ns (deny)" \
  e2e-alpha-isolated-a ws-alpha "${IP_ISOLATED_B}"

assert_deny "03 isolated→project same-ns (deny)" \
  e2e-alpha-isolated-a ws-alpha "${IP_PROJECT_A}"
