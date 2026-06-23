#!/usr/bin/env bash

# OpenMP Setup - Automatic OpenMP installer for macOS
# Copyright (C) 2025: James J Balamuta
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
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

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

show_help() {
    echo -e "${GREEN}OpenMP correctness test${NC}"
    echo "Usage: $0 [--c-only] [-h|--help]"
    echo ""
    echo "  Compiles and runs OpenMP programs (C, and an R package) against the"
    echo "  installed mac.r-project.org runtime and verifies real multithreading"
    echo "  AND a deterministic parallel-reduction result."
    echo ""
    echo "  --c-only   Run only the C toolchain check (skip the R package check)"
    echo "  -h, --help Show this help"
    echo ""
    echo "Exit codes: 0 pass, 1 single-thread, 2 _OPENMP undefined,"
    echo "  3 wrong C result, 4 R unavailable/install failed, 5 wrong R result,"
    echo "  6 C compile failed."
    exit 0
}

C_ONLY=false
for arg in "$@"; do
    case $arg in
        -h|--help) show_help ;;
        --c-only) C_ONLY=true ;;
        *) echo -e "${RED}Error: Unknown option '$arg'${NC}"; echo "Use --help"; exit 1 ;;
    esac
done

if [[ "$OSTYPE" != darwin* ]]; then
    echo -e "${YELLOW}SKIP: test-openmp.sh validates the macOS OpenMP runtime; current OS is not macOS.${NC}"
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

run_c_test() {
    cat > "$TMP/omp_test.c" <<'EOF'
#include <stdio.h>
#include <omp.h>
int main(void) {
#ifndef _OPENMP
    fprintf(stderr, "FAIL: _OPENMP not defined\n");
    return 2;
#endif
    int observed = 0;
    #pragma omp parallel
    {
        #pragma omp critical
        { int t = omp_get_num_threads(); if (t > observed) observed = t; }
    }
    const long N = 1000000L;
    long long expected = (long long)N * (N + 1) / 2;  /* 500000500000 */
    long long sum = 0;
    #pragma omp parallel for reduction(+:sum)
    for (long i = 1; i <= N; ++i) sum += i;
    printf("observed_threads=%d reduction_sum=%lld expected=%lld\n", observed, sum, expected);
    if (sum != expected) return 3;
    if (observed <= 1) return 1;
    return 0;
}
EOF
    echo "Compiling C OpenMP test..."
    if ! clang -Xclang -fopenmp -I/usr/local/include -L/usr/local/lib -lomp \
            "$TMP/omp_test.c" -o "$TMP/omp_test"; then
        echo -e "${RED}FAIL: C OpenMP program did not compile.${NC}"
        return 6
    fi

    local out rc
    out=$("$TMP/omp_test") && rc=0 || rc=$?
    echo "  default run: $out"
    case $rc in
        0) ;;
        1) echo -e "${RED}FAIL: OpenMP linked but ran single-threaded.${NC}"; return 1 ;;
        2) echo -e "${RED}FAIL: _OPENMP not defined (OpenMP not enabled).${NC}"; return 2 ;;
        3) echo -e "${RED}FAIL: parallel reduction produced the wrong result.${NC}"; return 3 ;;
        *) echo -e "${RED}FAIL: C test exited with unexpected code $rc.${NC}"; return $rc ;;
    esac

    local out4 obs4
    out4=$(OMP_NUM_THREADS=4 "$TMP/omp_test") || true
    echo "  OMP_NUM_THREADS=4 run: $out4"
    obs4=$(printf '%s\n' "$out4" | sed -n 's/.*observed_threads=\([0-9]*\).*/\1/p')
    if [ "$obs4" != "4" ]; then
        echo -e "${RED}FAIL: runtime did not honor OMP_NUM_THREADS=4 (observed=$obs4).${NC}"
        return 1
    fi
    echo -e "${GREEN}C toolchain OpenMP check passed.${NC}"
}

run_c_test

if [ "$C_ONLY" = true ]; then
    echo -e "${GREEN}All requested OpenMP correctness checks passed (C only).${NC}"
    exit 0
fi

run_r_test() {
    if ! command -v Rscript >/dev/null 2>&1; then
        echo -e "${RED}FAIL: Rscript not found; R package OpenMP check cannot run.${NC}"
        return 4
    fi

    local pkg="$TMP/ompcheck" lib="$TMP/lib"
    mkdir -p "$pkg/R" "$pkg/src" "$lib"

    cat > "$pkg/DESCRIPTION" <<'EOF'
Package: ompcheck
Version: 0.0.1
Title: OpenMP CI Correctness Probe
Description: Minimal package running a parallel reduction to verify OpenMP.
Authors@R: person("CI", "Probe", email = "ci@example.com", role = c("aut", "cre"))
License: AGPL (>= 3)
EOF

    printf 'useDynLib(ompcheck, .registration = TRUE)\nexport(omp_sum)\n' > "$pkg/NAMESPACE"
    printf 'omp_sum <- function(n) .Call(C_omp_sum, as.numeric(n))\n' > "$pkg/R/omp_sum.R"

    # NOTE: <omp.h> MUST be included before the R headers. R's headers before
    # omp.h break omp.h's `declare variant` parsing on recent Apple clang.
    cat > "$pkg/src/omp_sum.c" <<'EOF'
#include <omp.h>
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

SEXP C_omp_sum(SEXP nSEXP) {
    long N = (long) Rf_asReal(nSEXP);
    int observed = 0;
    #pragma omp parallel
    {
        #pragma omp critical
        { int t = omp_get_num_threads(); if (t > observed) observed = t; }
    }
    double sum = 0.0;
    #pragma omp parallel for reduction(+:sum)
    for (long i = 1; i <= N; ++i) sum += (double) i;
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 2));
    REAL(out)[0] = sum;
    REAL(out)[1] = (double) observed;
    UNPROTECT(1);
    return out;
}

static const R_CallMethodDef CallEntries[] = {
    {"C_omp_sum", (DL_FUNC) &C_omp_sum, 1},
    {NULL, NULL, 0}
};
void R_init_ompcheck(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
EOF

    echo "Building R package 'ompcheck' with OpenMP (documented flags)..."
    if ! PKG_CPPFLAGS='-Xclang -fopenmp -I/usr/local/include' \
         PKG_LIBS='-L/usr/local/lib -lomp' \
         R CMD INSTALL -l "$lib" "$pkg" >/dev/null 2>"$TMP/rinstall.log"; then
        echo -e "${RED}FAIL: R CMD INSTALL of the OpenMP package failed.${NC}"
        sed 's/^/    /' "$TMP/rinstall.log" | tail -15
        return 4
    fi

    echo "Running R package OpenMP check..."
    if ! Rscript -e '.libPaths(c("'"$lib"'", .libPaths()))
v <- ompcheck::omp_sum(1e6)
cat(sprintf("  R result: sum=%.0f observed_threads=%d\n", v[1], as.integer(v[2])))
stopifnot(v[1] == 1e6 * (1e6 + 1) / 2, v[2] > 1)
cat("  R parallel reduction correct and multithreaded.\n")'; then
        echo -e "${RED}FAIL: R OpenMP package produced a wrong or single-threaded result.${NC}"
        return 5
    fi
    echo -e "${GREEN}R package OpenMP check passed.${NC}"
}

run_r_test
echo -e "${GREEN}All OpenMP correctness checks passed.${NC}"
