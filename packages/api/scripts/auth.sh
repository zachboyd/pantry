#!/bin/bash

# Auth CLI Helper Script
# Usage: npm run auth <operation>
# Example: npm run auth signup

API_URL="http://localhost:3001"

case "$1" in
  signup)
    echo "=== Sign Up ==="
    read -p "Email: " email
    read -s -p "Password: " password
    echo
    read -p "Name: " name
    
    echo "Creating user account..."
    curl -X POST "$API_URL/api/auth/sign-up/email" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"$email\",\"password\":\"$password\",\"name\":\"$name\"}" \
      -w "\n\nHTTP Status: %{http_code}\n"
    ;;
    
  signin)
    echo "=== Sign In ==="
    read -p "Email: " email
    read -s -p "Password: " password
    echo
    
    echo "Signing in..."
    curl -X POST "$API_URL/api/auth/sign-in/email" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
      -c cookies.txt \
      -w "\n\nHTTP Status: %{http_code}\n"
    echo "Session saved to cookies.txt"
    ;;
    
  verify-email)
    echo "=== Verify Email ==="
    read -p "Verification token: " token
    
    echo "Verifying email..."
    curl -X GET "$API_URL/api/auth/verify-email?token=$token" \
      -w "\n\nHTTP Status: %{http_code}\n" \
      -L
    ;;
    
  change-email)
    echo "=== Change Email ==="
    read -p "New email: " new_email
    
    if [ ! -f cookies.txt ]; then
      echo "No session found. Please sign in first with 'npm run auth signin'"
      exit 1
    fi
    
    echo "Requesting email change..."
    curl -X POST "$API_URL/api/auth/change-email" \
      -H "Content-Type: application/json" \
      -d "{\"newEmail\":\"$new_email\"}" \
      -b cookies.txt \
      -w "\n\nHTTP Status: %{http_code}\n"
    ;;
    
  verify-email-change)
    echo "=== Verify Email Change ==="
    read -p "Verification token: " token
    
    if [ ! -f cookies.txt ]; then
      echo "No session found. Please sign in first with 'npm run auth signin'"
      exit 1
    fi
    
    echo "Verifying email change..."
    curl -X GET "$API_URL/api/auth/verify-email-change?token=$token" \
      -b cookies.txt \
      -w "\n\nHTTP Status: %{http_code}\n" \
      -L
    ;;
    
  session)
    echo "=== Get Session ==="
    
    if [ ! -f cookies.txt ]; then
      echo "No session found. Please sign in first with 'npm run auth signin'"
      exit 1
    fi
    
    echo "Getting current session..."
    curl -X GET "$API_URL/api/auth/session" \
      -b cookies.txt \
      -w "\n\nHTTP Status: %{http_code}\n"
    ;;
    
  signout)
    echo "=== Sign Out ==="
    
    if [ ! -f cookies.txt ]; then
      echo "No session found."
      exit 1
    fi
    
    echo "Signing out..."
    curl -X POST "$API_URL/api/auth/sign-out" \
      -b cookies.txt \
      -w "\n\nHTTP Status: %{http_code}\n"
    
    rm -f cookies.txt
    echo "Session cleared."
    ;;
    
  *)
    echo "Auth CLI Helper"
    echo "Usage: npm run auth <operation>"
    echo ""
    echo "Available operations:"
    echo "  signup              - Create new user account"
    echo "  signin              - Sign in and save session"
    echo "  verify-email        - Verify email with token"
    echo "  change-email        - Request email change (requires session)"
    echo "  verify-email-change - Verify email change with token (requires session)"
    echo "  session             - Get current session info"
    echo "  signout             - Sign out and clear session"
    echo ""
    echo "Examples:"
    echo "  npm run auth signup"
    echo "  npm run auth signin"
    echo "  npm run auth verify-email"
    ;;
esac