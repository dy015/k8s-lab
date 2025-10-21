#!/bin/bash

# Color codes for terminal output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m'

# Background colors
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'

# Text styles
export BOLD='\033[1m'
export DIM='\033[2m'
export UNDERLINE='\033[4m'
export BLINK='\033[5m'
export REVERSE='\033[7m'
export HIDDEN='\033[8m'

# Symbols
export CHECK_MARK="${GREEN}✓${NC}"
export CROSS_MARK="${RED}✗${NC}"
export WARNING_SIGN="${YELLOW}⚠${NC}"
export INFO_SIGN="${BLUE}ℹ${NC}"
export ARROW="${CYAN}→${NC}"
export BULLET="${WHITE}•${NC}"

# Spinner characters
export SPIN

NERS='-\|/'

# Helper function to print colored text
color_print() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}
