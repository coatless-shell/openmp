#!/bin/bash

# OpenMP Checker - Compilation checker for OpenMP on R macOS
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

# Note: We don't use 'set -e' here because we want to continue testing even
# when individual tests fail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}OpenMP Compilation Checker for R on macOS${NC}"
echo "=========================="

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script is designed for macOS only.${NC}"
    exit 1
fi

# Function to report test results
report_test() {
    local test_name="$1"
    local success="$2"
    local error_msg="$3"

    if [[ "$success" == "true" ]]; then
        echo -e "${GREEN}  ✓ PASS: $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}  ✗ FAIL: $test_name${NC}"
        if [[ -n "$error_msg" ]]; then
            echo -e "${RED}    → $error_msg${NC}"
        fi
        ((TESTS_FAILED++))
    fi
}

# Create temporary directory for tests
TEMP_DIR=$(mktemp -d)
if [[ ! -d "$TEMP_DIR" ]]; then
    echo -e "${RED}Error: Failed to create temporary directory${NC}"
    exit 1
fi
cd "$TEMP_DIR"

# Create test C program
cat > test_openmp.c << 'EOF'
#include <stdio.h>
#include <omp.h>

int main() {
    int nthreads = 0;
    int max_threads = omp_get_max_threads();

    printf("OpenMP version: %d\n", _OPENMP);
    printf("Max threads available: %d\n", max_threads);

    #pragma omp parallel
    {
        #pragma omp critical
        {
            nthreads = omp_get_num_threads();
        }
    }

    printf("Threads used in parallel region: %d\n", nthreads);

    if (nthreads > 1) {
        printf("OpenMP is working correctly!\n");
        return 0;
    } else {
        printf("OpenMP is not parallelizing properly.\n");
        return 1;
    }
}
EOF

echo ""
echo "1. Checking OpenMP Installation"
echo "================================"

# Check library existence
if [[ -f "/usr/local/lib/libomp.dylib" ]]; then
    report_test "libomp.dylib found" "true"

    # Check library info
    echo "   Library details:"
    file /usr/local/lib/libomp.dylib | sed 's/^/   /'
else
    report_test "libomp.dylib found" "false" "Library not found at /usr/local/lib/libomp.dylib - OpenMP not installed"
fi

# Check headers
HEADERS=("omp.h" "ompt.h" "omp-tools.h")
for header in "${HEADERS[@]}"; do
    if [[ -f "/usr/local/include/$header" ]]; then
        report_test "$header found" "true"
    else
        report_test "$header found" "false" "Header missing at /usr/local/include/$header"
    fi
done

echo ""
echo "2. Checking Compiler"
echo "===================="

# Check clang availability
if command -v clang &> /dev/null; then
    report_test "clang available" "true"
    CLANG_VERSION=$(clang --version | head -n1)
    echo "   $CLANG_VERSION"
else
    report_test "clang available" "false" "clang compiler not found - install Xcode Command Line Tools"
fi

echo ""
echo "3. Testing Compilation"
echo "======================"

# Test 1: Compile with explicit flags
echo "Testing compilation with explicit flags..."
COMPILE_ERROR=$(clang -Xclang -fopenmp -I/usr/local/include -L/usr/local/lib -lomp test_openmp.c -o test_explicit 2>&1)
if [[ $? -eq 0 ]]; then
    report_test "Explicit flags compilation" "true"
else
    report_test "Explicit flags compilation" "false" "Compilation failed - check OpenMP installation"
    echo "   Compiler errors:"
    echo "$COMPILE_ERROR" | sed 's/^/   /'
fi

# Test 2: Test execution
if [[ -f "test_explicit" ]]; then
    echo "Testing execution..."
    if ./test_explicit > output.txt 2>&1; then
        report_test "Program execution" "true"

        # Check if parallelization worked
        if grep -q "OpenMP is working correctly!" output.txt; then
            report_test "Parallel execution" "true"
        else
            report_test "Parallel execution" "false" "OpenMP not parallelizing - using only 1 thread"
        fi

        echo "   Program output:"
        sed 's/^/   /' output.txt

    else
        report_test "Program execution" "false" "Program crashed or failed to run"
        echo "   Error output:"
        sed 's/^/   /' output.txt
    fi
else
    echo -e "${RED}   → Skipping execution test - compilation failed${NC}"
fi

echo ""
echo "4. Testing R Configuration"
echo "=========================="

# Check ~/.R/Makevars
if [[ -f ~/.R/Makevars ]]; then
    if grep -q "fopenmp" ~/.R/Makevars && grep -q "\-lomp" ~/.R/Makevars; then
        report_test "~/.R/Makevars configured" "true"
        echo "   Found OpenMP flags in ~/.R/Makevars:"
        grep -E "(fopenmp|lomp)" ~/.R/Makevars | sed 's/^/   /'
    else
        report_test "~/.R/Makevars configured" "false" "OpenMP flags missing from ~/.R/Makevars"
        echo "   ~/.R/Makevars exists but no OpenMP flags found"
        echo "   Add these lines to ~/.R/Makevars:"
        echo -e "${GREEN}   CPPFLAGS += -Xclang -fopenmp${NC}"
        echo -e "${GREEN}   LDFLAGS += -lomp${NC}"
    fi
else
    report_test "~/.R/Makevars exists" "false" "File ~/.R/Makevars not found"
    echo "   Create ~/.R/Makevars with these lines:"
    echo -e "${GREEN}   CPPFLAGS += -Xclang -fopenmp${NC}"
    echo -e "${GREEN}   LDFLAGS += -lomp${NC}"
fi

# Test compilation using R-style flags
if [[ -f ~/.R/Makevars ]]; then
    echo "Testing compilation using ~/.R/Makevars style..."

    # Extract flags from Makevars
    CPPFLAGS=""
    LDFLAGS=""

    if grep -q "CPPFLAGS" ~/.R/Makevars; then
        CPPFLAGS=$(grep "CPPFLAGS" ~/.R/Makevars | sed 's/.*CPPFLAGS[[:space:]]*+=[[:space:]]*//' | tr -d '"')
    fi

    if grep -q "LDFLAGS" ~/.R/Makevars; then
        LDFLAGS=$(grep "LDFLAGS" ~/.R/Makevars | sed 's/.*LDFLAGS[[:space:]]*+=[[:space:]]*//' | tr -d '"')
    fi

    if [[ -n "$CPPFLAGS" && -n "$LDFLAGS" ]]; then
        MAKEVARS_ERROR=$(clang $CPPFLAGS -I/usr/local/include -L/usr/local/lib $LDFLAGS test_openmp.c -o test_makevars 2>&1)
        if [[ $? -eq 0 ]]; then
            report_test "Makevars-style compilation" "true"
        else
            report_test "Makevars-style compilation" "false" "Compilation failed with Makevars flags"
            echo "   Compiler errors:"
            echo "$MAKEVARS_ERROR" | sed 's/^/   /'
        fi
    else
        report_test "Makevars flags extraction" "false" "Could not extract proper CPPFLAGS and LDFLAGS from ~/.R/Makevars"
    fi
else
    echo -e "${RED}   → Skipping Makevars test - ~/.R/Makevars not found${NC}"
fi

echo ""
echo "5. Environment Variables"
echo "========================"

# Check environment variables only if ~/.R/Makevars is not properly configured
if [[ -f ~/.R/Makevars ]] && grep -q "fopenmp" ~/.R/Makevars && grep -q "\-lomp" ~/.R/Makevars; then
    echo -e "${GREEN}   → Skipping environment variable check - ~/.R/Makevars is properly configured${NC}"
    report_test "Environment variables check" "true" ""
else
    echo "~/.R/Makevars not configured, checking R environment variables..."

    # Check if R is available
    if command -v R &> /dev/null; then
        # Get environment variables from R
        R_ENV_OUTPUT=$(R --slave --no-restore -e "
        pkg_cppflags <- Sys.getenv('PKG_CPPFLAGS', unset = '')
        pkg_libs <- Sys.getenv('PKG_LIBS', unset = '')
        cat('PKG_CPPFLAGS=', pkg_cppflags, '\n', sep='')
        cat('PKG_LIBS=', pkg_libs, '\n', sep='')
        " 2>/dev/null)

        if [[ $? -eq 0 ]]; then
            PKG_CPPFLAGS_R=$(echo "$R_ENV_OUTPUT" | grep "PKG_CPPFLAGS=" | sed 's/PKG_CPPFLAGS=//')
            PKG_LIBS_R=$(echo "$R_ENV_OUTPUT" | grep "PKG_LIBS=" | sed 's/PKG_LIBS=//')

            # Check PKG_CPPFLAGS in R
            if [[ -n "$PKG_CPPFLAGS_R" && "$PKG_CPPFLAGS_R" != "" ]]; then
                if [[ "$PKG_CPPFLAGS_R" == *"fopenmp"* ]]; then
                    report_test "R PKG_CPPFLAGS set correctly" "true"
                    echo "   R PKG_CPPFLAGS=$PKG_CPPFLAGS_R"
                else
                    report_test "R PKG_CPPFLAGS set correctly" "false" "PKG_CPPFLAGS exists in R but missing -fopenmp flag"
                    echo "   R PKG_CPPFLAGS=$PKG_CPPFLAGS_R (missing -fopenmp)"
                fi
            else
                report_test "R PKG_CPPFLAGS set" "false" "Environment variable PKG_CPPFLAGS not set in R"
                echo "   Set in R with: Sys.setenv(PKG_CPPFLAGS = '-Xclang -fopenmp')"
            fi

            # Check PKG_LIBS in R
            if [[ -n "$PKG_LIBS_R" && "$PKG_LIBS_R" != "" ]]; then
                if [[ "$PKG_LIBS_R" == *"lomp"* ]]; then
                    report_test "R PKG_LIBS set correctly" "true"
                    echo "   R PKG_LIBS=$PKG_LIBS_R"
                else
                    report_test "R PKG_LIBS set correctly" "false" "PKG_LIBS exists in R but missing -lomp flag"
                    echo "   R PKG_LIBS=$PKG_LIBS_R (missing -lomp)"
                fi
            else
                report_test "R PKG_LIBS set" "false" "Environment variable PKG_LIBS not set in R"
                echo "   Set in R with: Sys.setenv(PKG_LIBS = '-lomp')"
            fi
        else
            report_test "R environment check" "false" "Failed to query R environment variables"
        fi
    else
        report_test "R availability" "false" "R not found - cannot check R environment variables"
        echo "   Install R to use per-session environment variable method"
    fi
fi

# Cleanup
cd / 2>/dev/null || true
if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
fi

echo ""
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}"
    echo "🎉 SUCCESS: OpenMP is properly installed and working!"
    echo "All tests passed. You can now use OpenMP in your projects."
    echo -e "${NC}"
elif [[ $TESTS_PASSED -eq 0 ]]; then
    echo -e "${RED}"
    echo "❌ COMPLETE FAILURE: OpenMP is not working at all."
    echo "No tests passed. OpenMP needs to be installed and configured."
    echo -e "${NC}"

    echo ""
    echo -e "${YELLOW}REQUIRED ACTIONS:${NC}"
    echo "1. Install OpenMP: ./install-openmp.sh"
    echo "2. Configure R: Add flags to ~/.R/Makevars"
    echo "3. Re-run this checker: ./check-openmp.sh"

    exit 1
else
    echo -e "${YELLOW}"
    echo "⚠️  PARTIAL FAILURE: OpenMP is partially working."
    echo "$TESTS_FAILED test(s) failed. See detailed error messages above."
    echo -e "${NC}"

    echo ""
    echo -e "${YELLOW}COMMON FIXES FOR FAILED TESTS:${NC}"
    echo ""
    echo "If installation tests failed:"
    echo "  • Run: ./install-openmp.sh"
    echo ""
    echo "If configuration tests failed:"
    echo "  • Add to ~/.R/Makevars:"
    echo -e "    ${GREEN}CPPFLAGS += -Xclang -fopenmp${NC}"
    echo -e "    ${GREEN}LDFLAGS += -lomp${NC}"
    echo ""
    echo "If environment variable tests failed:"
    echo "  • In an R session, run:"
    echo -e "    ${GREEN}Sys.setenv(PKG_CPPFLAGS = '-Xclang -fopenmp')${NC}"
    echo -e "    ${GREEN}Sys.setenv(PKG_LIBS = '-lomp')${NC}"
    echo ""
    echo "If compilation tests failed:"
    echo "  • Check that Xcode Command Line Tools are installed"
    echo "  • Verify OpenMP library permissions"
    echo "  • Try reinstalling OpenMP"

    exit 1
fi

echo ""
echo "Done!"
