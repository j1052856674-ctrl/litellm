#!/bin/bash
source /home/administrator/litellm/.venv/bin/activate
nohup litellm --config /mnt/e/产品/litellm/config.yaml --port 4000 > /tmp/litellm.log 2>&1 &
echo "PID=$!"
