#!/bin/bash
# Verifier entrypoint: scores /app/tickets/*.json, writes /logs/verifier/reward.txt.
mkdir -p /logs/verifier
python3 /verifier/check_tickets.py > /logs/verifier/output.txt 2>&1
RC=$?
cat /logs/verifier/output.txt
if [ $RC -ne 0 ]; then
  echo 0 > /logs/verifier/reward.txt
fi
exit 0
