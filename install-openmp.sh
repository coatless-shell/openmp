#!/bin/bash

# OpenMP Setup - Automatic OpenMP installer for macOS
# Copyright (C) 2025: James J Balamuta
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

echo -e "${GREEN}OpenMP Setup for R on macOS${NC}"
echo "========================================="

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script is designed for macOS only.${NC}"
    exit 1
fi

# Check if Xcode command line tools are installed
if ! command -v clang &> /dev/null; then
    echo -e "${RED}Error: Xcode command line tools not found.${NC}"
    echo "Please install them with: xcode-select --install"
    exit 1
fi

# Get Apple clang version
CLANG_VERSION=$(clang --version | head -n1 | sed -n 's/.*clang-\([0-9]*\)\..*/\1/p')

if [[ -z "$CLANG_VERSION" ]]; then
    echo -e "${RED}Error: Could not detect Apple clang version.${NC}"
    exit 1
fi

echo "Detected Apple clang version: $CLANG_VERSION"

# Map clang version to OpenMP version
OPENMP_VERSION=""
DARWIN_TARGET=""
BASE_URL="https://mac.r-project.org/openmp"

case $CLANG_VERSION in
    1700)
        OPENMP_VERSION="19.1.0"
        DARWIN_TARGET="darwin20"
        ;;
    1600)
        OPENMP_VERSION="17.0.6"
        DARWIN_TARGET="darwin20"
        ;;
    1500)
        OPENMP_VERSION="16.0.4"
        DARWIN_TARGET="darwin20"
        ;;
    1403)
        OPENMP_VERSION="15.0.7"
        DARWIN_TARGET="darwin20"
        ;;
    1400)
        OPENMP_VERSION="14.0.6"
        DARWIN_TARGET="darwin20"
        ;;
    1316)
        OPENMP_VERSION="13.0.0"
        DARWIN_TARGET="darwin21"
        ;;
    1300)
        OPENMP_VERSION="12.0.1"
        DARWIN_TARGET="darwin20"
        ;;
    1205)
        OPENMP_VERSION="11.0.1"
        DARWIN_TARGET="darwin20"
        ;;
    1200)
        OPENMP_VERSION="10.0.0"
        DARWIN_TARGET="darwin17"
        ;;
    1103)
        OPENMP_VERSION="9.0.1"
        DARWIN_TARGET="darwin17"
        ;;
    1100)
        OPENMP_VERSION="8.0.1"
        DARWIN_TARGET="darwin17"
        ;;
    1001)
        OPENMP_VERSION="7.1.0"
        DARWIN_TARGET="darwin17"
        ;;
    *)
        echo -e "${RED}Error: Unsupported clang version $CLANG_VERSION${NC}"
        echo "Supported versions and their corresponding OpenMP builds:"
        echo "  1700 (Xcode 16.3+) → OpenMP 19.1.0"
        echo "  1600 (Xcode 16.0-16.2) → OpenMP 17.0.6"
        echo "  1500 (Xcode 15.x) → OpenMP 16.0.4"
        echo "  1403 (Xcode 14.3.x) → OpenMP 15.0.7"
        echo "  1400 (Xcode 14.0-14.2) → OpenMP 14.0.6"
        echo "  1316 (Xcode 13.3-13.4.1) → OpenMP 13.0.0"
        echo "  1300 (Xcode 13.0-13.2.1) → OpenMP 12.0.1"
        echo "  1205 (Xcode 12.5) → OpenMP 11.0.1"
        echo "  1200 (Xcode 12.0-12.4) → OpenMP 10.0.0"
        echo "  1103 (Xcode 11.4-11.7) → OpenMP 9.0.1"
        echo "  1100 (Xcode 11.0-11.3.1) → OpenMP 8.0.1"
        echo "  1001 (Xcode 10.2-10.3) → OpenMP 7.1.0"
        echo ""
        echo "Please check https://mac.r-project.org/openmp/ for updates."
        exit 1
        ;;
esac

TARBALL="openmp-${OPENMP_VERSION}-${DARWIN_TARGET}-Release.tar.gz"
DOWNLOAD_URL="${BASE_URL}/${TARBALL}"

echo "Selected OpenMP version: $OPENMP_VERSION"
echo "Download URL: $DOWNLOAD_URL"

# Check if already installed
if [[ -f "/usr/local/lib/libomp.dylib" ]]; then
    echo -e "${YELLOW}OpenMP library already exists at /usr/local/lib/libomp.dylib${NC}"
    read -p "Do you want to reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "Downloading $TARBALL..."
if curl -f -O "$DOWNLOAD_URL"; then
    echo -e "${GREEN}Download completed successfully.${NC}"
else
    echo -e "${RED}Error: Failed to download $TARBALL${NC}"
    echo "Please check your internet connection and try again."
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Installing OpenMP runtime..."
if sudo tar fvxz "$TARBALL" -C /; then
    echo -e "${GREEN}OpenMP $OPENMP_VERSION installed successfully!${NC}"
else
    echo -e "${RED}Error: Installation failed.${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Verify installation
if [[ -f "/usr/local/lib/libomp.dylib" ]]; then
    echo -e "${GREEN}Verification: libomp.dylib found at /usr/local/lib/${NC}"
    
    # Show installed files
    echo "Installed files:"
    ls -la /usr/local/lib/libomp.dylib
    ls -la /usr/local/include/omp*.h 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "To use OpenMP in your projects, you have three options:"
    echo ""
    echo "1. Per-package installation:"
    echo "   PKG_CPPFLAGS='-Xclang -fopenmp' PKG_LIBS=-lomp R CMD INSTALL myPackage"
    echo ""
    echo -e "${YELLOW}2. Global installation (RECOMMENDED):${NC}"
    echo "   Add the following to ~/.R/Makevars:"
    echo ""
    echo -e "${GREEN}   CPPFLAGS += -Xclang -fopenmp${NC}"
    echo -e "${GREEN}   LDFLAGS += -lomp${NC}"
    echo ""
    echo "   This will enable OpenMP for all R packages that support it."
    echo -e "${YELLOW}   Note: Always check ~/.R/Makevars when upgrading R, macOS, or Xcode!${NC}"
    echo ""
    echo "3. Per-session compilation (in R):"
    echo "   Run this in your R session before installing packages:"
    echo ""
    echo -e "${GREEN}   Sys.setenv(PKG_CPPFLAGS = '-Xclang -fopenmp')${NC}"
    echo -e "${GREEN}   Sys.setenv(PKG_LIBS = '-lomp')${NC}"
    echo ""
    echo "   Then use: install.packages('myPackage', type = 'source')"
else
    echo -e "${RED}Error: Installation verification failed.${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo "Done!"
