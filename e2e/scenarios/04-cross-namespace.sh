#!/usr/bin/env bash

IP_BETA_ISOLATED_A="$(pod_ip e2e-beta-isolated-a ws-beta)"
IP_BETA_PROJECT_A="$(pod_ip e2e-beta-project-a ws-beta)"

assert_deny "04 alpha-isolated→beta-isolated (deny)" \
  e2e-alpha-isolated-a ws-alpha "${IP_BETA_ISOLATED_A}"

assert_deny "08 alpha-project→beta-project (deny)" \
  e2e-alpha-project-a ws-alpha "${IP_BETA_PROJECT_A}"
