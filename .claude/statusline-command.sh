#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON input
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')

# Get directory name
dir_name=$(basename "$current_dir")

# Count items from specified directories
# - Services count from ~/Projects/FoundryServices/Services
# - Commands from ${PAI_HOME}/.claude/commands/
# - MCPs from settings.json
# - Patterns from ${PAI_HOME}/.config/fabric/patterns
claude_dir="${PAI_HOME:-/Users/daniel}/.claude"
commands_count=0
mcps_count=0
fobs_count=0
fabric_count=0

# Count commands (only .md files in root of commands directory, not subdirectories)
if [ -d "$claude_dir/commands" ]; then
    commands_count=$(find "$claude_dir/commands" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi

# Count MCPs from settings.json
if [ -f "$claude_dir/settings.json" ]; then
    mcps_count=$(jq -r '.mcpServers | keys | length' "$claude_dir/settings.json" 2>/dev/null || echo "0")
else
    mcps_count="0"
fi

# Count Services from FoundryServices directory
services_dir="${PAI_HOME:-/Users/daniel}/Projects/FoundryServices/Services"
if [ -d "$services_dir" ]; then
    fobs_count=$(find "$services_dir" -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi

# Count Fabric patterns from ~/.config/fabric/patterns
fabric_patterns_dir="${PAI_HOME:-/Users/daniel}/.config/fabric/patterns"
if [ -d "$fabric_patterns_dir" ]; then
    fabric_count=$(find "$fabric_patterns_dir" -maxdepth 1 -type d ! -path "$fabric_patterns_dir" 2>/dev/null | wc -l | tr -d ' ')
fi

# Get today's usage data from ccusage (for line 3)
daily_tokens=""
daily_cost=""
if command -v bunx >/dev/null 2>&1; then
    # Get today's date in YYYY-MM-DD format
    today=$(date +%Y-%m-%d)

    # Run ccusage daily with JSON output
    ccusage_output=$(bunx ccusage daily --json 2>/dev/null)
    if [ -n "$ccusage_output" ]; then
        # Parse JSON to extract today's tokens and cost only
        # Filter for today's date and extract values
        daily_input=$(echo "$ccusage_output" | jq -r --arg today "$today" '.daily[] | select(.date == $today) | .inputTokens // 0')
        daily_output=$(echo "$ccusage_output" | jq -r --arg today "$today" '.daily[] | select(.date == $today) | .outputTokens // 0')
        daily_cost=$(echo "$ccusage_output" | jq -r --arg today "$today" '.daily[] | select(.date == $today) | .totalCost // 0')

        # Calculate total tokens if both are valid numbers
        if [[ "$daily_input" =~ ^[0-9]+$ ]] && [[ "$daily_output" =~ ^[0-9]+$ ]]; then
            daily_total=$((daily_input + daily_output))
            # Format tokens with commas
            daily_tokens=$(printf "%'d" "$daily_total" 2>/dev/null || echo "$daily_total")
        fi

        # Format cost to 2 decimal places
        if [[ "$daily_cost" != "0" ]] && [[ -n "$daily_cost" ]]; then
            daily_cost=$(printf "$%.2f" "$daily_cost" 2>/dev/null || echo "$daily_cost")
        fi
    fi
fi

# Tokyo Night Storm Color Scheme
# Background: #24283b (dark blue-gray)
# Foreground: #c0caf5 (light blue-white)
# Blue: #7aa2f7
# Purple: #bb9af7  
# Green: #9ece6a
# Orange: #ff9e64
# Red: #f7768e
# Yellow: #e0af68
# Cyan: #7dcfff

# Tokyo Night Storm - Line-Based Color Scheme
# Design Philosophy: Each line has a distinct dominant color for visual separation

# Base colors
BACKGROUND='\033[48;2;36;40;59m'     # #24283b - Dark blue-gray background
BRIGHT_PURPLE='\033[38;2;187;154;247m'  # #bb9af7 - Line 1 primary color
BRIGHT_BLUE='\033[38;2;122;162;247m'     # #7aa2f7 - Line 2 primary color
DARK_BLUE='\033[38;2;100;140;200m'       # Darker blue variant for Line 2
BRIGHT_GREEN='\033[38;2;158;206;106m'    # #9ece6a - Line 3 primary color  
DARK_GREEN='\033[38;2;130;170;90m'       # Darker green variant for Line 3
BRIGHT_ORANGE='\033[38;2;255;158;100m'   # #ff9e64 - Line 4 cost color
BRIGHT_RED='\033[38;2;247;118;142m'      # #f7768e - Bright red for errors

# Line-specific color assignments
# LINE 1 - MOSTLY PURPLE (#bb9af7)
LINE1_PRIMARY="$BRIGHT_PURPLE"       # Primary purple for most line 1 content
LINE1_ACCENT='\033[38;2;160;130;210m' # Slightly different purple shade for variety
MODEL_PURPLE='\033[38;2;138;99;210m'  # Different purple for model name - deeper violet
KAI_PURPLE='\033[38;2;147;112;219m'   # Different purple for "Kai" - medium violet

# LINE 2 - MOSTLY DARK BLUE 
LINE2_PRIMARY="$DARK_BLUE"           # Primary dark blue for most line 2 content
LINE2_ACCENT='\033[38;2;110;150;210m' # Slightly different blue shade for variety

# LINE 3 - MOSTLY DARK GREEN
LINE3_PRIMARY="$DARK_GREEN"          # Primary dark green for most line 3 content
LINE3_ACCENT='\033[38;2;140;180;100m' # Slightly different green shade for variety

# LINE 3 - All green scheme
COST_COLOR="$LINE3_ACCENT"           # Cost in green
TOKENS_COLOR='\033[38;2;169;177;214m' # Tokens in light gray

# Separators and punctuation - subtle for all lines
SEPARATOR_COLOR='\033[38;2;140;152;180m' # #8c98b4 - Subtle gray for separators

# Individual MCP names - use line 2 blue scheme with accent colors for important ones
MCP_DAEMON="$BRIGHT_BLUE"            # Daemon - bright blue accent
MCP_STRIPE="$LINE2_ACCENT"           # Stripe - blue accent (keeping in line 2 theme)
MCP_DEFAULT="$LINE2_PRIMARY"         # All other MCPs - standard line 2 blue

RESET='\033[0m'                      # Reset all formatting

# Get MCP names for line 2 with blue color scheme
mcp_names_formatted=""
if [ -f "$claude_dir/settings.json" ]; then
    mcp_names_raw=$(jq -r '.mcpServers | keys[]' "$claude_dir/settings.json" 2>/dev/null | tr '\n' ' ')
    # Format MCP names - line 2 blue scheme with accent colors for important ones
    for mcp in $mcp_names_raw; do
        case "$mcp" in
            "daemon") formatted="${MCP_DAEMON}Daemon${RESET}" ;;             # Bright blue accent: Personal API
            "stripe") formatted="${MCP_STRIPE}Stripe${RESET}" ;;             # Blue accent: Financial ops
            # All other MCPs use line 2 blue
            "httpx") formatted="${MCP_DEFAULT}HTTPx${RESET}" ;;
            "brightdata") formatted="${MCP_DEFAULT}BrightData${RESET}" ;;
            "naabu") formatted="${MCP_DEFAULT}Naabu${RESET}" ;;
            "apify") formatted="${MCP_DEFAULT}Apify${RESET}" ;;
            "content") formatted="${MCP_DEFAULT}Content${RESET}" ;;
            "Ref") formatted="${MCP_DEFAULT}Ref${RESET}" ;;
            "pai") formatted="${MCP_DEFAULT}Foundry${RESET}" ;;
            "playwright") formatted="${MCP_DEFAULT}Playwright${RESET}" ;;
            *) formatted="${MCP_DEFAULT}${mcp^}${RESET}" ;;                  # Capitalize first letter, line 2 blue
        esac
        
        if [ -z "$mcp_names_formatted" ]; then
            mcp_names_formatted="$formatted"
        else
            mcp_names_formatted="$mcp_names_formatted${SEPARATOR_COLOR}, ${formatted}"
        fi
    done
fi

# Output the line-based color themed statusline
# Light blue color for directory
DIR_COLOR='\033[38;2;135;206;250m'  # Light sky blue for directory

# LINE 1 - MOSTLY PURPLE: Complete first line with all counts (services, commands, MCPs, patterns)
printf "${KAI_PURPLE}Kai${RESET}${LINE1_PRIMARY} here, running on ${MODEL_PURPLE}🧠 ${model_name}${RESET}${LINE1_PRIMARY} in ${DIR_COLOR}📁 ${dir_name}${RESET}${LINE1_PRIMARY}, wielding: ${RESET}${LINE1_PRIMARY}🔧 ${fobs_count} Services${RESET}${LINE1_PRIMARY}, ${RESET}${LINE1_PRIMARY}⚙️ ${commands_count} Commands${RESET}${LINE1_PRIMARY}, ${RESET}${LINE1_PRIMARY}🔌 ${mcps_count} MCPs${RESET}${LINE1_PRIMARY}, and ${RESET}${LINE1_PRIMARY}📚 ${fabric_count} Patterns${RESET}\n"

# LINE 2 - MOSTLY DARK BLUE: MCP names list  
printf "${LINE2_PRIMARY}🔌 MCPs${RESET}${LINE2_PRIMARY}${SEPARATOR_COLOR}: ${RESET}${mcp_names_formatted}${RESET}\n"

# LINE 3 - MOSTLY DARK GREEN: Daily tokens and cost
printf "${LINE3_PRIMARY}💎 Today's Tokens${RESET}${LINE3_PRIMARY}${SEPARATOR_COLOR}: ${RESET}${LINE3_ACCENT}${daily_tokens:-N/A}${RESET}${LINE3_PRIMARY}  Today's Cost${RESET}${LINE3_PRIMARY}${SEPARATOR_COLOR}: ${RESET}${COST_COLOR}${daily_cost:-N/A}${RESET}\n"