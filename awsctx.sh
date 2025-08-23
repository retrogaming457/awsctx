#!/bin/bash
# Script: awsctx.sh
# Purpose: AWS/S3 context switcher for Linux bash
# Author: Hamed Davodi
# Date: 2025-08-21

AWS_DIR="$HOME/.aws"
CRED_FILE="$AWS_DIR/credentials"
CONF_FILE="$AWS_DIR/config"
CACHE_FILE="$AWS_DIR/.bashrc_awsctx"
CERT_FILE="$AWS_DIR/certificate.pem"
S3CFG_FILE="$HOME/.s3cfg"


# Define color and style variables
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[1;90m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
WHITE='\033[1;37m'

BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'

RESET='\033[0m'


# Prompt user to choose profile using fzf (fuzzy-finder)
PROFILE=$(grep '^\[' "$CRED_FILE" | awk -F'[][]' '{print $2}' | fzf)

if [[ -z "$PROFILE" ]]; then
  echo -e "${CYAN}[awsctx]${RESET} ${GRAY}No profile selected.${RESET}"
  return 0
fi

# Use AWS CLI to extract endpoint_url, region, access_key and secret_key
ENDPOINT=$(aws configure get endpoint_url --profile "$PROFILE" 2>/dev/null)
REGION=$(aws configure get region --profile "$PROFILE" 2>/dev/null)
ACCESS_KEY=$(aws configure get aws_access_key_id --profile "$PROFILE" 2>/dev/null)
SECRET_KEY=$(aws configure get aws_secret_access_key --profile "$PROFILE" 2>/dev/null)


# Validate endpoint_url and region
# Fallback: manually parse config file if it has a service-specific format and values of
# endpoint_url and region are nested under `s3 =` which is not visible to `aws configure get`
if [[ -z "$ENDPOINT" || -z "$REGION" ]]; then

  # Extract the service section name from [profile $PROFILE]
  SERVICE_NAME=$(sed -n "/^\[profile $PROFILE\]/,/^\[/p" "$CONF_FILE" \
    | grep -E '^\s*services\s*=' \
    | sed -E 's/.*=\s*//')

  # Fallback: if no services= found, use profile name as service name
  if [[ -z "$SERVICE_NAME" ]]; then
    SERVICE_NAME="$PROFILE"
  fi

  # Look under [services SERVICE_NAME] section for endpoint_url value
   ENDPOINT=$(awk -v svc="$SERVICE_NAME" '
       $0 ~ "^[[:space:]]*\\[services[[:space:]]+" svc "\\]" { in_section=1; next }
       in_section && /^\s*\[/ { in_section=0 }
       in_section && /^\s*s3\s*=/ { in_s3=1; next }
       in_section && /^\s*\[/ { in_s3=0 }
       in_section && in_s3 && /^\s*endpoint_url\s*=/ {
           sub(/.*=\s*/, "", $0); print; exit
       }
   ' "$CONF_FILE")

   # Look under [services SERVICE_NAME] section for region value
   REGION=$(awk -v svc="$SERVICE_NAME" '
       $0 ~ "^[[:space:]]*\\[services[[:space:]]+" svc "\\]" { in_section=1; next }
       in_section && /^\s*\[/ { in_section=0 }
       in_section && /^\s*s3\s*=/ { in_s3=1; next }
       in_section && /^\s*\[/ { in_s3=0 }
       in_section && in_s3 && /^\s*region\s*=/ {
           sub(/.*=\s*/, "", $0); print; exit
       }
   ' "$CONF_FILE")

  # Validate endpoint_url for the last time
  if [[ -z "$ENDPOINT" ]]; then
    echo -e "${CYAN}[awsctx]${RESET} ${GRAY}ERROR: endpoint_url not found.${RESET}"
    return 1
  fi

  # Validate region for the last time
  if [[ -z "$REGION" ]]; then
    echo -e "${CYAN}[awsctx]${RESET} ${GRAY}ERROR: region not found.${RESET}"
    return 1
  fi
fi


# Validate access_key
if [[ -z "$ACCESS_KEY" ]]; then
  echo -e "${CYAN}[awsctx]${RESET} ${GRAY}ERROR: aws_access_key_id not found.${RESET}"
  return 1
fi

# Validate secret_key
if [[ -z "$SECRET_KEY" ]]; then
  echo -e "${CYAN}[awsctx]${RESET} ${GRAY}ERROR: aws_secret_access_key not found.${RESET}"
  return 1
fi


# Strip protocol for HOST_BASE, add underline to HOST_BUCKET
if [[ -n "$ENDPOINT" ]]; then
  HOST_BASE="${ENDPOINT#http://}"
  HOST_BASE="${HOST_BASE#https://}"
  HOST_BUCKET="${HOST_BASE}_"
else
  HOST_BASE=""
  HOST_BUCKET=""
fi


# Build ~/.s3cfg file for s3cmd & s4cmd
{
  echo "[default]"
  [[ -n "$HOST_BASE" ]] && {
    echo "host_base = $HOST_BASE"
    echo "host_bucket = $HOST_BUCKET"
  }
  echo "access_key = $ACCESS_KEY"
  echo "secret_key = $SECRET_KEY"
  echo "use_https = True"
  echo "check_ssl_certificate = True"
  echo "preserve = False"
  echo "progress_meter = False"

} > "$S3CFG_FILE"


# Export environment variables for aws & s5cmd
export AWS_PROFILE="$PROFILE"
export AWS_REGION="$REGION"
export AWS_ENDPOINT_URL="$ENDPOINT"
export S3_ENDPOINT_URL="$ENDPOINT"


# Cache variables for next bash login
{
   echo "export AWS_PROFILE=$AWS_PROFILE"
   echo "export AWS_REGION=$AWS_REGION"
   echo "export AWS_ENDPOINT_URL=$AWS_ENDPOINT_URL"
   echo "export S3_ENDPOINT_URL=$S3_ENDPOINT_URL"

} > "$CACHE_FILE"


# CERT_CASE: export certificate conditionally (subject to change depending on your envirnoment)
if [[ "$PROFILE" == "dbaas-production" ]]; then
  export AWS_CA_BUNDLE="$CERT_FILE"
  echo "ca_certs_file = $CERT_FILE" >> "$S3CFG_FILE"
  echo "export AWS_CA_BUNDLE=$AWS_CA_BUNDLE" >> "$CACHE_FILE"
else
  unset AWS_CA_BUNDLE
fi


# Print summary on shell
echo -e "${CYAN}[awsctx]${RESET} ${WHITE}${BOLD} aws  / s5cmd${RESET} → ${GREEN}${AWS_PROFILE}${RESET} ${WHITE}${DIM}profile${RESET} ✅"
echo -e "${CYAN}[awsctx]${RESET} ${WHITE}${BOLD}s4cmd / s3cmd${RESET} → ${GREEN}${AWS_PROFILE}${RESET} ${WHITE}${DIM}profile${RESET} ✅ ${WHITE}${DIM}Updated${RESET} → ${YELLOW}$S3CFG_FILE${RESET} ✅"
echo "+---------------------------------+"
echo "|       Exported Variables        |"
echo "+---------------------------------+"
echo -e "  ${WHITE}AWS_PROFILE=${GREEN}$AWS_PROFILE${RESET}"
echo -e "  ${WHITE}AWS_REGION=${GREEN}$AWS_REGION${RESET}"

[[ -n "$AWS_CA_BUNDLE" ]] && echo -e "  ${WHITE}AWS_CA_BUNDLE=${GREEN}$AWS_CA_BUNDLE${RESET}"

echo -e "  ${WHITE}AWS_ENDPOINT_URL=${GREEN}$AWS_ENDPOINT_URL${RESET}"
echo -e "  ${WHITE}S3_ENDPOINT_URL=${GREEN}$S3_ENDPOINT_URL${RESET}"