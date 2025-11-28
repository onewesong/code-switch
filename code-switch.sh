#!/bin/bash
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color
init() { 
    mkdir -p ~/.code-switch
    touch ~/.claude/settings.json &&  ln ~/.claude/settings.json ~/.code-switch/settings.json
    cd ~/.code-switch && git init -b default && git add . && git commit -m "backup"
}
branch() {
    cd ~/.code-switch && git branch
}
switch-branch() {
    cd ~/.code-switch
    PS3="Enter the number to switch: "
    select branch in $(git branch | sed 's/*//'); do
        if [ -n "$branch" ]; then
            git switch "$branch"
            break
        else
            echo "Invalid choice."
        fi
    done
}

add() {
    BASE_URL=$1
    API_KEY=$2
    MODEL=$3
    cd ~/.code-switch

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required for JSON manipulation. Please install jq first.${NC}"
        echo -e "${YELLOW}Install with: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)${NC}"
        exit 1
    fi
    DOMAIN=$(echo "$BASE_URL" | sed -n 's|https\?://\([^/]*\).*|\1|p' | sed 's/^www\.//' | awk -F. '{print $(NF-1)}')
    BRANCH_NAME="${MODEL}@${DOMAIN}"
    new_config=$(cat <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "$BASE_URL",
    "ANTHROPIC_AUTH_TOKEN": "$API_KEY",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1,
    "ANTHROPIC_MODEL": "$MODEL",
    "ANTHROPIC_SMALL_FAST_MODEL": "$MODEL"
  }
}
EOF
)
    if [ -s "settings.json" ]; then
        merged_config=$(jq --argjson new_env "$(echo "$new_config" | jq '.env')" '.env = $new_env' settings.json)
        echo "$merged_config" > settings.json
    else
        echo "$new_config" > settings.json
    fi

    if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
        git checkout "$BRANCH_NAME"
    else
        git checkout -b "$BRANCH_NAME"
    fi
    git add settings.json
    git commit -m "add $MODEL by $BASE_URL"
}
delete() {
    cd ~/.code-switch
    current_branch=$(git symbolic-ref --short HEAD)
    if [ "$current_branch" = "$1" ]; then
        echo -e "${RED}Error: cannot delete current configuration of '$1'. Please switch to another configuration first.${NC}"
        exit 1
    fi
    git branch -D "$1"
}
if [ ! -e ~/.code-switch ]; then
    init
fi
case "$1" in
    add)
        if [ $# -ne 4 ]; then
            echo -e "${RED}Invalid arguments: add requires 3 parameters${NC}"
            echo -e "${CYAN}Usage: code-switch add <BASE_URL> <API_KEY> <MODEL>${NC}"
            echo -e "${YELLOW}Example: code-switch add https://api.edgefn.net sk-abcdefg glm-4.6${NC}"
            exit 1
        fi
        add "$2" "$3" "$4"
        ;;
    delete)
        if [ $# -ne 2 ]; then
            echo -e "${RED}Invalid arguments: delete requires 1 parameter${NC}"
            echo -e "${CYAN}Usage: code-switch delete <MODEL>@<DOMAIN>${NC}"
            exit 1
        fi
        delete "$2"
        ;;
    check)
        less ~/.code-switch/settings.json
        ;;
    "")
        if [ "$(branch | sed 's/*//' | xargs)" = "default" ]; then
            echo -e "${GREEN}The original configuration has been saved to the 'default' branch.${NC}"
            echo -e "${CYAN}Use: code-switch add <BASE_URL> <API_KEY> <MODEL> to add a new configuration.${NC}"
            echo -e "${YELLOW}Example: code-switch add https://api.edgefn.net sk-abcdefg glm-4.6${NC}"
            exit 0
        fi
        switch-branch
        ;;
    *)
        echo -e "${WHITE}Usage:${NC}"
        echo -e "  ${CYAN}code-switch add <BASE_URL> <API_KEY> <MODEL>${NC}   ${GREEN}# Add a new AI provider configuration${NC}"
        echo -e "  ${CYAN}code-switch delete <MODEL>@<DOMAIN>${NC}            ${RED}# Delete a configuration${NC}"
        echo -e "  ${CYAN}code-switch check${NC}                              ${YELLOW}# Show current configuration${NC}"
        ;;
esac