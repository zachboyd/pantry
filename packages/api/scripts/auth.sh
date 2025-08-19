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
    
  social-signin)
    echo "=== Social Sign In ==="
    
    if [ -z "$2" ]; then
      echo "Provider is required"
      echo "Usage: npm run auth social-signin <provider>"
      echo "Available providers: google, github, discord, etc."
      exit 1
    fi
    
    provider="$2"
    echo "Initiating social sign-in with $provider..."
    
    # Make request to get OAuth URL
    response=$(curl -s -X POST "$API_URL/api/auth/sign-in/social" \
      -H "Content-Type: application/json" \
      -d "{\"provider\":\"$provider\"}")
    
    # Check if response contains URL
    if echo "$response" | grep -q '"url"'; then
      # Extract URL from JSON response
      oauth_url=$(echo "$response" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p' | sed 's/\\//g')
      
      if [ -n "$oauth_url" ]; then
        echo "Opening OAuth URL in browser..."
        echo "URL: $oauth_url"
        echo ""
        
        # Cross-platform browser opening
        if command -v open >/dev/null 2>&1; then
          # macOS
          open "$oauth_url"
        elif command -v xdg-open >/dev/null 2>&1; then
          # Linux
          xdg-open "$oauth_url"
        elif command -v start >/dev/null 2>&1; then
          # Windows
          start "$oauth_url"
        else
          echo "Could not auto-open browser. Please manually visit the URL above."
        fi
        
        echo "After completing OAuth:"
        echo "1. Sign in with your $provider account"
        echo "2. Grant permissions"
        echo "3. You'll be redirected back to the app"
        echo "4. Run 'npm run auth session' to verify your session"
      else
        echo "Error: Could not extract OAuth URL from response"
        echo "Response: $response"
      fi
    else
      echo "Error response:"
      echo "$response"
    fi
    ;;

  social-callback)
    echo "=== Social OAuth Callback Info ==="
    echo "After completing OAuth in your browser, you should be redirected"
    echo "to your application. If you see a 404, that's normal since this"
    echo "is an API-only server."
    echo ""
    echo "To verify your social sign-in worked, run:"
    echo "  npm run auth session"
    echo ""
    echo "The callback URLs for different providers are:"
    echo "  Google:  $API_URL/api/auth/callback/google"
    echo "  GitHub:  $API_URL/api/auth/callback/github"
    echo "  Discord: $API_URL/api/auth/callback/discord"
    echo ""
    echo "These should be configured in your OAuth app settings."
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
    echo "Email Authentication:"
    echo "  signup              - Create new user account"
    echo "  signin              - Sign in and save session"
    echo "  verify-email        - Verify email with token"
    echo "  change-email        - Request email change (requires session)"
    echo "  verify-email-change - Verify email change with token (requires session)"
    echo ""
    echo "Social Authentication:"
    echo "  social-signin <provider>  - Sign in with social provider (google, github, etc.)"
    echo "  social-callback           - Show callback URL info and instructions"
    echo ""
    echo "Session Management:"
    echo "  session             - Get current session info"
    echo "  signout             - Sign out and clear session"
    echo ""
    echo "Examples:"
    echo "  npm run auth signup"
    echo "  npm run auth signin"
    echo "  npm run auth social-signin google"
    echo "  npm run auth session"
    echo "  npm run auth signout"
    ;;
esac