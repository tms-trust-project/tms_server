#!/bin/bash
#
# Basic smoke test http calls for TMS Server
#
# This script uses httpie to make the http requests. https://httpie.io/cli
#
# Calls are made to three endpoints: get version, get pubkey and create keypair.
#
# The following environment variables are used in testing.
# They all have defaults that are suitable for testing against localhost:8080.
# Note that default test data is pre-seeded at server start up.
# If non-default values are used, e.g. for TMS_PUBKEY_FINGERPRINT, then the test data most be manually seeded.
#
# The value you will be most likely want to change at times is TMS_URL, the location of the TMS Server under test.
# By default the test is run against localhost:8080
export TMS_URL="${TMS_URL:-http://localhost:8080}"

export TMS_IDENTITY="${TMS_IDENTITY:-testtmsuser101@DangerModeTestIdP}"
export TMS_RP_ID="${TMS_RP_ID:-test_fake_rp}"
export TMS_RP_ACCOUNT="${TMS_RP_ACCOUNT:-testrpaccount101}"

export TMS_CLIENT_ID="${TMS_CLIENT_ID:-testclient1}"
export TMS_CLIENT_SECRET="${TMS_CLIENT_SECRET:-secret1}"
export TMS_PUBKEY_FINGERPRINT="${TMS_PUBKEY_FINGERPRINT:-SHA256:0EddP3z8IwV4YqzewwoiJVyfKhmFj4VlsDBZqCaan24}"
export TMS_PUBKEY_HOST="${TMS_PUBKEY_HOST:-testhost101}"
export TMS_PUBKEY_KEYTYPE="${TMS_PUBKEY_KEYTYPE:-ed25519}"
export TMS_PUBKEY_USER="${TMS_PUBKEY_USER:-testhostaccount101}"
export TMS_PUBKEY_USERID="${TMS_PUBKEY_USERID:-101}"
export TMS_HOST_ACCOUNT="${TMS_HOST_ACCOUNT:-testhostaccount101}"

#
# Determine absolute path to location from which we are running and change to that directory.
RUN_DIR=$(pwd)
PRG_RELPATH=$(dirname "$0")
cd "$PRG_RELPATH"/. || exit
PRG_PATH=$(pwd)

FINAL_RESULT="PASS"
echo "**********************************************************************"
echo "   Testing get version"
echo "**********************************************************************"
http ${TMS_URL}/v1/tms/version
RET_CODE=$?
echo "**********************************************************************"
if [ $RET_CODE -ne 0 ]; then
  echo "Result : FAIL"
  FINAL_RESULT="FAIL"
else
  echo "Result : PASS"
fi
echo "**********************************************************************"

echo "**********************************************************************"
echo "   Testing get pubkey"
echo "**********************************************************************"
http --check-status POST ${TMS_URL}/v1/tms/pubkeys/creds/retrieve Content-type:application/json \
    user=testhostaccount101 user_uid:=101 host=testhost101 key_type=ed25519 \
    public_key_fingerprint='SHA256:0EddP3z8IwV4YqzewwoiJVyfKhmFj4VlsDBZqCaan24'
RET_CODE=$?
echo "**********************************************************************"
if [ $RET_CODE -ne 0 ]; then
  echo "Result : FAIL"
  FINAL_RESULT="FAIL"
else
  echo "Result : PASS"
fi
echo "**********************************************************************"
echo "**********************************************************************"
echo "   Testing create keypair"
echo "**********************************************************************"
http --check-status POST ${TMS_URL}/v1/tms/pubkeys/creds Content-type:application/json \
     X-TMS-CLIENT-ID:${TMS_CLIENT_ID} X-TMS-CLIENT-SECRET:${TMS_CLIENT_SECRET} \
     tms_identity=${TMS_IDENTITY} rp_id=${TMS_RP_ID} rp_account=${TMS_RP_ACCOUNT} \
     host=${TMS_PUBKEY_HOST} host_account=${TMS_HOST_ACCOUNT} num_uses:=1 ttl_minutes:=1 key_type=${TMS_PUBKEY_KEYTYPE}
RET_CODE=$?
echo "**********************************************************************"
if [ $RET_CODE -ne 0 ]; then
  echo "Result : FAIL"
  FINAL_RESULT="FAIL"
else
  echo "Result : PASS"
fi
echo "======================================================================================"
echo "Final Result: $FINAL_RESULT"
echo "======================================================================================"
if [ $FINAL_RESULT = "FAIL" ]; then
  exit 1
fi
