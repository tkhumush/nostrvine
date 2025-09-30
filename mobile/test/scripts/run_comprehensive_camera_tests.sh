#!/bin/bash
# ABOUTME: Comprehensive test runner script for all camera-related tests
# ABOUTME: Runs unit, integration, performance, and visual tests with coverage

set -e

echo "🎥 OpenVine Camera Test Suite Runner"
echo "===================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Function to run test category
run_test_category() {
    local category=$1
    local path=$2

    echo -e "${YELLOW}Running $category tests...${NC}"

    if flutter test $path --coverage --coverage-path=coverage/$category.info; then
        echo -e "${GREEN}✓ $category tests passed${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ $category tests failed${NC}"
        ((FAILED_TESTS++))
    fi

    ((TOTAL_TESTS++))
    echo ""
}

# Function to check platform
check_platform() {
    case "$OSTYPE" in
        darwin*)  PLATFORM="macOS" ;;
        linux*)   PLATFORM="Linux" ;;
        msys*)    PLATFORM="Windows" ;;
        *)        PLATFORM="unknown" ;;
    esac

    echo "Platform detected: $PLATFORM"
}

# Main test execution
main() {
    check_platform

    echo "Starting comprehensive camera test suite..."
    echo "Time: $(date)"
    echo ""

    # Clean previous coverage
    rm -rf coverage
    mkdir -p coverage

    # Unit Tests
    run_test_category "Unit - Native macOS Camera" "test/services/native_macos_camera_test.dart"
    run_test_category "Unit - Camera Interface" "test/services/macos_camera_interface_test.dart"
    run_test_category "Unit - Recording Provider" "test/providers/vine_recording_provider_test.dart"
    run_test_category "Unit - Enhanced Mobile Camera" "test/services/camera/enhanced_mobile_camera_interface_test.dart"

    # Integration Tests
    if [ "$1" != "--skip-integration" ]; then
        echo -e "${YELLOW}Running integration tests (requires device/simulator)...${NC}"
        flutter test integration_test/camera_recording_integration_test.dart || true
        echo ""
    fi

    # Performance Tests
    run_test_category "Performance" "test/performance/camera_initialization_benchmark_test.dart"

    # Cross-platform Tests
    run_test_category "Cross-platform" "test/cross_platform/platform_compatibility_test.dart"

    # Edge Case Tests
    run_test_category "Edge Cases" "test/edge_cases/camera_error_recovery_test.dart"

    # Visual Regression Tests (if golden toolkit available)
    if flutter pub deps | grep -q golden_toolkit; then
        run_test_category "Visual Regression" "test/visual/camera_ui_regression_test.dart"
    else
        echo -e "${YELLOW}Skipping visual regression tests (golden_toolkit not installed)${NC}"
        ((SKIPPED_TESTS++))
    fi

    # E2E Tests (requires mocks to be generated)
    if [ -f "test/e2e/complete_upload_workflow_test.mocks.dart" ]; then
        run_test_category "E2E Upload" "test/e2e/complete_upload_workflow_test.dart"
    else
        echo -e "${YELLOW}Generating mocks for E2E tests...${NC}"
        flutter pub run build_runner build --delete-conflicting-outputs
        run_test_category "E2E Upload" "test/e2e/complete_upload_workflow_test.dart"
    fi

    # Generate combined coverage report
    if [ -d "coverage" ]; then
        echo -e "${YELLOW}Generating coverage report...${NC}"

        # Combine all coverage files
        lcov --add-tracefile coverage/Unit*.info \
             --add-tracefile coverage/Performance.info \
             --add-tracefile coverage/Cross-platform.info \
             --add-tracefile coverage/Edge*.info \
             -o coverage/lcov.info 2>/dev/null || true

        # Generate HTML report
        if command -v genhtml &> /dev/null; then
            genhtml coverage/lcov.info -o coverage/html
            echo -e "${GREEN}Coverage report generated in coverage/html/index.html${NC}"
        fi

        # Calculate coverage percentage
        if [ -f "coverage/lcov.info" ]; then
            COVERAGE=$(lcov --summary coverage/lcov.info 2>/dev/null | grep "lines" | sed 's/.*: \([0-9.]*\)%.*/\1/' || echo "N/A")
            echo "Overall coverage: $COVERAGE%"
        fi
    fi

    echo ""
    echo "===================================="
    echo "Test Suite Summary"
    echo "===================================="
    echo -e "Total test categories: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo -e "${YELLOW}Skipped: $SKIPPED_TESTS${NC}"
    echo ""

    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
        exit 1
    fi
}

# Parse arguments
case "$1" in
    --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --skip-integration    Skip integration tests"
        echo "  --coverage-only       Only generate coverage report"
        echo "  --help               Show this help message"
        exit 0
        ;;
    --coverage-only)
        echo "Generating coverage report from existing data..."
        lcov --add-tracefile coverage/*.info -o coverage/lcov.info
        genhtml coverage/lcov.info -o coverage/html
        open coverage/html/index.html
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac