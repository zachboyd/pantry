#!/bin/bash

# Create and Merge PR Script
# Automates the process of creating a GitHub PR and optionally merging it immediately

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to prompt for user input
prompt_input() {
    local prompt_text="$1"
    local var_name="$2"
    echo -e "${BLUE}$prompt_text${NC}"
    read -r "$var_name"
}

# Function to prompt for multiline input
prompt_multiline() {
    local prompt_text="$1"
    local var_name="$2"
    echo -e "${BLUE}$prompt_text${NC}"
    echo -e "${YELLOW}(Press Ctrl+D when finished, or type 'END' on a new line)${NC}"
    
    local input=""
    local line
    while IFS= read -r line; do
        if [[ "$line" == "END" ]]; then
            break
        fi
        if [[ -n "$input" ]]; then
            input="$input"$'\n'"$line"
        else
            input="$line"
        fi
    done
    
    eval "$var_name=\$input"
}

# Function to confirm action
confirm_action() {
    local prompt_text="$1"
    local response
    echo -e "${YELLOW}$prompt_text (y/N):${NC}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

main() {
    # Parse command line arguments
    local pr_title="$1"
    local pr_description="$2"
    
    print_status "🚀 GitHub PR Creation and Merge Script"
    echo

    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed. Please install it first:"
        print_error "brew install gh"
        exit 1
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        print_error "Not in a git repository!"
        exit 1
    fi

    # Check if user is authenticated with GitHub
    if ! gh auth status &> /dev/null; then
        print_error "Not authenticated with GitHub. Please run: gh auth login"
        exit 1
    fi

    # Get current branch
    current_branch=$(git branch --show-current)
    print_status "Current branch: $current_branch"

    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "You have uncommitted changes!"
        if confirm_action "Do you want to continue anyway?"; then
            print_status "Continuing with uncommitted changes..."
        else
            print_error "Please commit your changes first."
            exit 1
        fi
    fi

    # Check if current branch is main/master
    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        print_error "You're on the $current_branch branch. Please create a feature branch first."
        exit 1
    fi

    echo
    print_status "📝 PR Details"
    echo

    # Get PR title - use argument or prompt
    if [[ -z "$pr_title" ]]; then
        prompt_input "Enter PR title:" pr_title
        if [[ -z "$pr_title" ]]; then
            print_error "PR title cannot be empty!"
            exit 1
        fi
    else
        print_status "Using provided title: $pr_title"
    fi

    echo

    # Get PR description - use argument or prompt
    if [[ -z "$pr_description" ]]; then
        prompt_multiline "Enter PR description (multiline supported):" pr_description
        if [[ -z "$pr_description" ]]; then
            print_warning "No description provided. Using default description."
            pr_description="Automated PR created via script."
        fi
    else
        print_status "Using provided description: $pr_description"
    fi

    echo
    print_status "📋 PR Summary"
    echo "Title: $pr_title"
    echo "Description: $pr_description"
    echo "Branch: $current_branch"
    echo

    # Confirm PR creation
    if ! confirm_action "Create PR with these details?"; then
        print_error "PR creation cancelled."
        exit 1
    fi

    # Create the PR
    print_status "Creating PR..."
    
    local pr_url
    if pr_url=$(gh pr create --title "$pr_title" --body "$pr_description" 2>&1); then
        print_success "PR created successfully!"
        echo "$pr_url"
        
        # Extract PR number from URL
        local pr_number
        pr_number=$(echo "$pr_url" | grep -o '/pull/[0-9]\+' | grep -o '[0-9]\+')
        
        echo
        print_status "PR #$pr_number is ready for review."
        
        # Ask if user wants to merge immediately
        if confirm_action "Do you want to merge this PR immediately?"; then
            print_status "Merging PR #$pr_number..."
            
            # Ask for merge strategy
            echo
            print_status "Select merge strategy:"
            echo "1) Merge commit (default)"
            echo "2) Squash and merge"
            echo "3) Rebase and merge"
            
            local merge_strategy
            prompt_input "Enter choice (1-3, default: 1):" merge_strategy
            
            case "$merge_strategy" in
                2)
                    merge_flag="--squash"
                    ;;
                3)
                    merge_flag="--rebase"
                    ;;
                *)
                    merge_flag="--merge"
                    ;;
            esac
            
            # Ask if user wants to delete branch after merge
            local delete_branch=""
            if confirm_action "Delete feature branch after merge?"; then
                delete_branch="--delete-branch"
            fi
            
            # Perform the merge
            if gh pr merge "$pr_number" "$merge_flag" $delete_branch; then
                print_success "PR #$pr_number merged successfully! 🎉"
                
                # Switch back to main if branch was deleted
                if [[ -n "$delete_branch" ]]; then
                    print_status "Switched back to main branch."
                fi
                
                echo
                print_success "🚀 All done! Your changes are now live on main."
            else
                print_error "Failed to merge PR #$pr_number"
                exit 1
            fi
        else
            print_status "PR created but not merged. You can merge it later with:"
            print_status "gh pr merge $pr_number --merge --delete-branch"
        fi
        
    else
        print_error "Failed to create PR:"
        echo "$pr_url"
        exit 1
    fi
}

# Run the main function
main "$@" 