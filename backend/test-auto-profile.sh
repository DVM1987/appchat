#!/bin/bash

# Test auto profile creation
echo "=== Testing Auto Profile Creation ==="

# 1. Register new user
echo -e "\n1. Registering new user..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:5002/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "auto-test-'$(date +%s)'@example.com",
    "password": "Password123!",
    "fullName": "Auto Test User"
  }')

echo "Register Response: $REGISTER_RESPONSE"

# Extract userId from response
USER_ID=$(echo $REGISTER_RESPONSE | grep -o '"userId":"[^"]*' | sed 's/"userId":"//')
echo "User ID: $USER_ID"

# 2. Wait a moment for profile creation
echo -e "\n2. Waiting for profile creation..."
sleep 3

# 3. Check if profile was created
echo -e "\n3. Checking User Service for profile..."
PROFILE_RESPONSE=$(curl -s http://localhost:5004/api/v1/users/identity/$USER_ID)

echo "Profile Response: $PROFILE_RESPONSE"

if [[ $PROFILE_RESPONSE == *"identityId"* ]]; then
    echo -e "\n✅ SUCCESS: User profile was auto-created!"
else
    echo -e "\n❌ FAIL: Profile not found. Check logs."
fi
