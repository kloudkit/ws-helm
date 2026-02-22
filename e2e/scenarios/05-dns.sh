#!/usr/bin/env bash

assert_dns "14a isolated→dns (allow)" e2e-alpha-isolated-a ws-alpha

assert_dns "14b project→dns (allow)" e2e-alpha-project-a ws-alpha
