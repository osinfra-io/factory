#!/usr/bin/env bash

# Ownership marker for the dedicated local gateway-stack cluster. Changing these
# values requires a full Docker Desktop Kubernetes reset and fresh setup.

# Constants consumed by scripts sourcing this file.
# shellcheck disable=SC2034
readonly OWNER_CONFIGMAP="local-gateway-stack-owner"
# shellcheck disable=SC2034
readonly OWNER_NAMESPACE="kube-system"
# shellcheck disable=SC2034
readonly OWNER_VALUE="osinfra-local-gateway-stack"
