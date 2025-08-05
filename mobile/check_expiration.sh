#!/bin/bash
# Check for expiration tags in kind 32222 events

echo "Fetching kind 32222 events from relay3.openvine.co..."
nak req -k 32222 -l 5 wss://relay3.openvine.co 2>/dev/null > /tmp/events.txt

echo "Checking for expiration tags..."
while IFS= read -r line; do
    if echo "$line" | grep -q '"expiration"'; then
        echo "Found expiration tag in event:"
        echo "$line" | jq -r '.id'
        echo "$line" | jq -r '.tags[] | select(.[0] == "expiration")'
    fi
done < /tmp/events.txt

# Also check the full structure of the first event
echo ""
echo "Full structure of first event:"
head -1 /tmp/events.txt | jq '.'