#!/bin/bash

# OpenMP Setup - Uninstaller for OpenMP runtime on macOS
# Copyright (C) 2025
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}OpenMP Uninstaller for R on macOS${NC}"
echo "=================================="

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script is designed for macOS only.${NC}"
    exit 1
fi

# Define OpenMP files to remove
OPENMP_LIB="/usr/local/lib/libomp.dylib"
OPENMP_HEADERS=(
    "/usr/local/include/omp.h"
    "/usr/local/include/ompt.h"
    "/usr/local/include/omp-tools.h"
    "/usr/local/include/ompx.h"
)

# Check what's currently installed
INSTALLED_FILES=()
MISSING_FILES=()

if [[ -f "$OPENMP_LIB" ]]; then
    INSTALLED_FILES+=("$OPENMP_LIB")
else
    MISSING_FILES+=("$OPENMP_LIB")
fi

for header in "${OPENMP_HEADERS[@]}"; do
    if [[ -f "$header" ]]; then
        INSTALLED_FILES+=("$header")
    else
        MISSING_FILES+=("$header")
    fi
done

# Report current status
if [[ ${#INSTALLED_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No OpenMP files found. OpenMP may not be installed.${NC}"
    exit 0
fi

echo "Found OpenMP installation:"
for file in "${INSTALLED_FILES[@]}"; do
    echo -e "${GREEN}  ✓ $file${NC}"
done

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo ""
    echo "Missing files (not installed or already removed):"
    for file in "${MISSING_FILES[@]}"; do
        echo -e "${YELLOW}  - $file${NC}"
    done
fi

echo ""
echo -e "${RED}WARNING: This will remove OpenMP from your system.${NC}"
echo "Any packages compiled with OpenMP may stop working until you reinstall OpenMP."
echo ""

# Confirmation prompt
read -p "Do you want to proceed with uninstallation? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo "Removing OpenMP files..."

# Remove files
REMOVED_COUNT=0
FAILED_COUNT=0

for file in "${INSTALLED_FILES[@]}"; do
    if sudo rm -f "$file" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Removed: $file${NC}"
        ((REMOVED_COUNT++))
    else
        echo -e "${RED}  ✗ Failed to remove: $file${NC}"
        ((FAILED_COUNT++))
    fi
done

echo ""

# Summary
if [[ $FAILED_COUNT -eq 0 ]]; then
    echo -e "${GREEN}OpenMP successfully uninstalled!${NC}"
    echo "Removed $REMOVED_COUNT file(s)."
else
    echo -e "${YELLOW}Uninstallation completed with $FAILED_COUNT error(s).${NC}"
    echo "Removed $REMOVED_COUNT file(s), failed to remove $FAILED_COUNT file(s)."
fi

# Cleanup suggestions
echo ""
echo -e "${YELLOW}Additional cleanup (optional):${NC}"
echo ""
echo "1. Remove OpenMP flags from ~/.R/Makevars if present:"
echo "   - CPPFLAGS += -Xclang -fopenmp"
echo "   - LDFLAGS += -lomp"
echo ""
echo "2. If you set environment variables in R sessions:"
echo "   - Restart R or unset PKG_CPPFLAGS and PKG_LIBS"
echo ""
echo "3. You may need to reinstall packages that were compiled with OpenMP"

echo ""
echo "Done!"
