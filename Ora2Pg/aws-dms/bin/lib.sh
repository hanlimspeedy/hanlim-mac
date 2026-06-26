#!/usr/bin/env bash
# Shared helpers for the wrtp AWS DMS migration scripts. Source this at the top:
#   . "$(dirname "$0")/lib.sh"
set -euo pipefail

AWSDMS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # the aws-dms/ directory
CONFIG="$AWSDMS_DIR/config.env"

if [ ! -f "$CONFIG" ]; then
  cp "$AWSDMS_DIR/config.env.example" "$CONFIG"
  echo "NOTE: created $CONFIG from example — review/fill it before the later steps." >&2
fi
set -a
# shellcheck disable=SC1090
. "$CONFIG"
set +a

export AWS_DEFAULT_REGION="${AWS_REGION:-ap-northeast-2}"
[ -n "${AWS_PROFILE:-}" ] && export AWS_PROFILE

WRTP_PREFIX="${WRTP_PREFIX:-wrtp}"
TAG_KEY="${WRTP_TAG_KEY:-Project}"
TAG_VALUE="${WRTP_TAG_VALUE:-wrtp}"

OUTPUT_DIR="$AWSDMS_DIR/output"
mkdir -p "$OUTPUT_DIR"

# wrtp-<short>  e.g. stack_name network -> wrtp-network
stack_name() { echo "${WRTP_PREFIX}-$1"; }

# Deploy one CloudFormation template with the wrtp tag (idempotent create/update).
#   deploy_stack <shortName> <templateFile> [Key=Value ...parameter overrides]
deploy_stack() {
  local short="$1" tpl="$2"; shift 2
  local name; name="$(stack_name "$short")"
  echo ">> deploying stack $name from $(basename "$tpl") ..."
  if [ "$#" -gt 0 ]; then
    aws cloudformation deploy --stack-name "$name" --template-file "$tpl" \
      --tags "${TAG_KEY}=${TAG_VALUE}" --capabilities CAPABILITY_NAMED_IAM \
      --parameter-overrides "$@"
  else
    aws cloudformation deploy --stack-name "$name" --template-file "$tpl" \
      --tags "${TAG_KEY}=${TAG_VALUE}" --capabilities CAPABILITY_NAMED_IAM
  fi
  echo ">> $name: $(aws cloudformation describe-stacks --stack-name "$name" --query 'Stacks[0].StackStatus' --output text)"
}

# Read a stack output value by OutputKey.
stack_output() { # <shortName> <OutputKey>
  aws cloudformation describe-stacks --stack-name "$(stack_name "$1")" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" --output text
}

aws_account_id() { aws sts get-caller-identity --query Account --output text; }

# Read one field from a wrtp Secrets Manager secret's JSON.
secret_field() { # <secret-name> <jsonKey>
  aws secretsmanager get-secret-value --secret-id "$1" --query SecretString --output text | jq -r ".$2 // empty"
}

# Does a CloudFormation stack exist?
stack_exists() { aws cloudformation describe-stacks --stack-name "$(stack_name "$1")" >/dev/null 2>&1; }

# Default S3 bucket name (deterministic).
default_bucket() { echo "${S3_BUCKET:-${WRTP_PREFIX}-sc-$(aws_account_id)-${AWS_DEFAULT_REGION}}"; }

# DMS Schema Conversion selection rule for the SOURCE Oracle schema.
# Must include server-name + database-name + schema-name, rule-action "explicit"
# (a bare schema-name locator is rejected with "locator 'schema-name' does not exist").
sc_source_rule() {
  jq -n --arg srv "$ORACLE_PUBLIC_IP" --arg s "$ORACLE_SCHEMA" \
    '{rules:[{"rule-type":"selection","rule-id":"1","rule-name":"1","object-locator":{"server-name":$srv,"schema-name":$s},"rule-action":"explicit"}]}'
}

# DMS Schema Conversion selection rule for the TARGET PostgreSQL schema.
#   sc_target_rule <target-server> <target-schema>
sc_target_rule() {
  jq -n --arg srv "$1" --arg s "$2" \
    '{rules:[{"rule-type":"selection","rule-id":"1","rule-name":"1","object-locator":{"server-name":$srv,"schema-name":$s},"rule-action":"explicit"}]}'
}

# Latest status of a DMS Schema Conversion async request type.
#   sc_status <describe-subcommand> <migration-project>
sc_status() { aws dms "$1" --migration-project-identifier "$2" --query 'Requests[0].Status' --output text 2>/dev/null; }

# Poll a DMS Schema Conversion async request until terminal. No blind sleeps.
#   wait_sc <describe-subcommand> <migration-project> [timeout-secs]
# returns 0 on SUCCESS, 1 on FAILURE, 2 on timeout.
wait_sc() {
  local sub="$1" proj="$2" timeout="${3:-1200}" waited=0 st
  while :; do
    st="$(sc_status "$sub" "$proj")"
    echo "   [$sub] ${st:-?} (${waited}s)"
    case "$st" in
      SUCCESS) return 0 ;;
      FAILURE|FAILED|ERROR) return 1 ;;
    esac
    [ "$waited" -ge "$timeout" ] && return 2
    sleep 15; waited=$((waited + 15))
  done
}
