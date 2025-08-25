# OpenMP Setup, Uninstall, and Checking via Shell

Automatically detects your Xcode version and installs the correct OpenMP runtime from the [R CRAN macOS tools](https://mac.r-project.org/openmp/). Includes configuration testing and uninstall scripts.

## Scripts

- `install-openmp.sh`: Main installer with auto-detection
- `check-openmp.sh`:  Compilation and configuration checker  
- `uninstall-openmp.sh`: Clean removal of OpenMP files

## Requirements

- macOS 10.13+ (High Sierra) or macOS 11+ (Big Sur) for Apple Silicon
- Xcode Command Line Tools (`xcode-select --install`)
- Admin privileges for installation

## Usage

```bash
# Download and run installer
curl -O https://raw.githubusercontent.com/coatless-shell/openmp/main/install-openmp.sh
chmod +x install-openmp.sh
./install-openmp.sh

# Check your installation
curl -O https://raw.githubusercontent.com/coatless-shell/openmp/main/check-openmp.sh
chmod +x check-openmp.sh
./check-openmp.sh

# Uninstall if needed
curl -O https://raw.githubusercontent.com/coatless-shell/openmp/main/uninstall-openmp.sh
chmod +x uninstall-openmp.sh
./uninstall-openmp.sh
```

## Supported Versions

| Xcode Version | Apple Clang | OpenMP Version | Download |
|---------------|-------------|----------------|----------|
| 16.3+ | 1700.x | 19.1.0 | [openmp-19.1.0-darwin20-Release.tar.gz](https://mac.r-project.org/openmp/openmp-19.1.0-darwin20-Release.tar.gz) |
| 16.0-16.2 | 1600.x | 17.0.6 | [openmp-17.0.6-darwin20-Release.tar.gz](https://mac.r-project.org/openmp/openmp-17.0.6-darwin20-Release.tar.gz) |
| 15.x | 1500.x | 16.0.4 | [openmp-16.0.4-darwin20-Release.tar.gz](https://mac.r-project.org/openmp/openmp-16.0.4-darwin20-Release.tar.gz) |
| 14.3.x | 1403.x | 15.0.7 | [openmp-15.0.7-darwin20-Release.tar.gz](https://mac.r-project.org/openmp/openmp-15.0.7-darwin20-Release.tar.gz) |
| 14.0-14.2 | 1400.x | 14.0.6 | [openmp-14.0.6-darwin20-Release.tar.gz](https://mac.r-project.org/openmp/openmp-14.0.6-darwin20-Release.tar.gz) |
| 13.3-13.4.1 | 1316.x | 13.0.0 | [openmp-13.0.0-darwin21-Release.tar.gz](https://mac.r-project.org/openmp/openmp-13.0.0-darwin21-Release.tar.gz) |
| 13.0-13.2.1 | 1300.x | 12.0.1 | [openmp-12.0.1-darwin20-Release.tar.gz](https://mac.r-project.org/openmp/openmp-12.0.1-darwin20-Release.tar.gz) |
| 12.5 | 1205.x | 11.0.1 | [openmp-11.0.1-darwin20-Release.tar.gz](https://mac.r-project.org/openmp/openmp-11.0.1-darwin20-Release.tar.gz) |
| 12.0-12.4 | 1200.x | 10.0.0 | [openmp-10.0.0-darwin17-Release.tar.gz](https://mac.r-project.org/openmp/openmp-10.0.0-darwin17-Release.tar.gz) |
| 11.4-11.7 | 1103.x | 9.0.1 | [openmp-9.0.1-darwin17-Release.tar.gz](https://mac.r-project.org/openmp/openmp-9.0.1-darwin17-Release.tar.gz) |
| 11.0-11.3.1 | 1100.x | 8.0.1 | [openmp-8.0.1-darwin17-Release.tar.gz](https://mac.r-project.org/openmp/openmp-8.0.1-darwin17-Release.tar.gz) |
| 10.2-10.3 | 1001.x | 7.1.0 | [openmp-7.1.0-darwin17-Release.tar.gz](https://mac.r-project.org/openmp/openmp-7.1.0-darwin17-Release.tar.gz) |

> [!NOTE]
>
> - OpenMP 11.0.1 and above include both Intel (x86_64) and Apple Silicon (arm64) support and require macOS 11+.
> - OpenMP 10.0.0 and below require macOS 10.13+ and are Intel-only.

## Installation

To place OpenMP headers on macOS for use with Apple's Xcode toolchain, please use:

```bash
# Download and run installer
curl -O https://raw.githubusercontent.com/coatless-shell/openmp/main/install-openmp.sh
chmod +x install-openmp.sh
./install-openmp.sh
```

> [!IMPORTANT]
>
> You will be prompted for your user account password to install files.


## Using OpenMP After Installation

### Option 1: Global Setup (Recommended)

Add to `~/.R/Makevars` for system-wide OpenMP support:

```makefile
CPPFLAGS += -Xclang -fopenmp
LDFLAGS += -lomp
```

> [!NOTE]
> 
> Once set, it will be applied universally across any package installations or
> local script compilations.

### Option 2: Per-Session (R)

Use when you prefer session-specific control or don't want permanent system changes:

```r
Sys.setenv(PKG_CPPFLAGS = '-Xclang -fopenmp')
Sys.setenv(PKG_LIBS = '-lomp')
install.packages('myPackage', type = 'source')
```

### Option 3: Per-Package (Shell)

For one-off package installations:

```bash
PKG_CPPFLAGS='-Xclang -fopenmp' PKG_LIBS=-lomp R CMD INSTALL myPackage
```

## Testing Your Installation

Having difficulties or are unsure if you have OpenMP installed correctly? Use:


```bash
# Download check script
curl -O https://raw.githubusercontent.com/coatless-shell/openmp/main/check-openmp.sh
chmod +x check-openmp.sh
```

### Full Tests (include R)

```bash
# Check your installation
./check-openmp.sh
```

### C/C++ Only (Skips R tests)

> [!NOTE]
>
> Not interested in R? No worries, you can safely skip those tests with `--disable-r`!

```bash
# C/C++ only tests (no R)
./check-openmp.sh --disable-r
```

### Test Overview

The `check-openmp.sh` script provides verification of your OpenMP setup with 5 test categories:

1. **Installation Check**: Verifies library and header files
2. **Compiler Verification**: Confirms clang is available and working  
3. **Compilation Testing**: Tests OpenMP compilation and execution
4. **R Configuration**: Checks `~/.R/Makevars` setup
5. **Environment Variables**: Validates R session variables (only if Makevars not configured)

The checker uses smart logic: 

- R-specific tests are skipped if `--disable-r` is passed, e.g.
    - Skip **4. R Configuration** and **5. Environment Variables** checks.
- If `~/.R/Makevars` is properly configured, it skips **5. Environment Variables** testing.
    - Otherwise, it queries R directly to check session-specific settings using `Sys.getenv()`.

## Uninstalling

To remove OpenMP:

```bash
curl -O https://raw.githubusercontent.com/coatless-shell/openmp/main/uninstall-openmp.sh
chmod +x uninstall-openmp.sh
./uninstall-openmp.sh
```

> [!IMPORTANT]
>
> You will be prompted for your user account password to delete files.

## Troubleshooting

**First, run the checker**: `./check-openmp.sh` provides detailed diagnostics and specific fix instructions for any issues.

Common issues and solutions:

- **"Unsupported clang version"**: Your Xcode version isn't supported. Check [mac.r-project.org/openmp](https://mac.r-project.org/openmp/) for updates
- **"Library not found"**: OpenMP isn't installed. Run `./install-openmp.sh`
- **"Compilation failed"**: Check that Xcode Command Line Tools are installed (`sudo xcode-select --install`)
- **"No parallelization"**: Verify configuration in `~/.R/Makevars` or R environment variables
- **"R not found"**: Either install R or use `--disable-r` flag for C/C++ only testing

## Related

Consider using the [`{macrtools}` _R_ package](https://github.com/coatless-mac/macrtools) to setup the development toolchain directly from _R_.

## License

AGPL (>= 3)
