#!/usr/bin/env bash

IP_ISOLATED_A="$(pod_ip e2e-alpha-isolated-a ws-alpha)"
IP_PROJECT_A="$(pod_ip e2e-alpha-project-a ws-alpha)"
IP_GLOBAL_B="$(pod_ip e2e-global-b workspace-system)"

assert_allow "09 global→isolated (allow)" \
  e2e-global-a workspace-system "${IP_ISOLATED_A}"

assert_allow "10 global→project (allow)" \
  e2e-global-a workspace-system "${IP_PROJECT_A}"

assert_allow "11 global→global same-ns (allow)" \
  e2e-global-a workspace-system "${IP_GLOBAL_B}"
