#!/usr/bin/env bash

IP_PROJECT_B="$(pod_ip e2e-alpha-project-b ws-alpha)"
IP_NGINX_PROJECT="$(pod_ip e2e-alpha-nginx-project ws-alpha)"
IP_GLOBAL_A="$(pod_ip e2e-global-a workspace-system)"
IP_ISOLATED_A="$(pod_ip e2e-alpha-isolated-a ws-alpha)"

assert_allow "05 project→project same-ns (allow)" \
  e2e-alpha-project-a ws-alpha "${IP_PROJECT_B}"

assert_allow "06 project→global (allow)" \
  e2e-alpha-project-a ws-alpha "${IP_GLOBAL_A}"

assert_deny "07 project→isolated same-ns (deny)" \
  e2e-alpha-project-a ws-alpha "${IP_ISOLATED_A}"

assert_allow "05b nginx-project→project (allow)" \
  e2e-alpha-nginx-project ws-alpha "${IP_PROJECT_B}"

assert_allow "06b project→nginx-project (allow)" \
  e2e-alpha-project-a ws-alpha "${IP_NGINX_PROJECT}"

assert_deny "07b nginx-project→isolated (deny)" \
  e2e-alpha-nginx-project ws-alpha "${IP_ISOLATED_A}"
