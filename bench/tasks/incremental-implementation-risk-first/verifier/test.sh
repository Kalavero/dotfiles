#!/bin/bash
# Verifier entrypoint: runs the acceptance + git-replay checks, writes
# /logs/verifier/reward.txt. Always exits 0.
mkdir -p /logs/verifier
python3 /verifier/check.py > /logs/verifier/output.txt 2>&1
RC=$?
cat /logs/verifier/output.txt
if [ $RC -ne 0 ]; then
  echo 0 > /logs/verifier/reward.txt
fi
exit 0
