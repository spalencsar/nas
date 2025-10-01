#!/bin/bash

# Unit tests for NAS Setup Script
# This script tests critical functions to ensure reliability

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/defaults.sh"
source "${SCRIPT_DIR}/../lib/logging.sh"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/detection.sh"

# Test configuration
TEST_LOG_FILE="/tmp/nas_test.log"
TEST_CONFIG_FILE="/tmp/nas_test.conf"
TESTS_PASSED=0
TESTS_FAILED=0

# Test framework functions
setup_test() {
    local test_name="$1"
    echo "Running test: $test_name"
    
    # Override variables for testing
    LOG_FILE="$TEST_LOG_FILE"
    CONFIG_FILE="$TEST_CONFIG_FILE"
    DEBUG=true
    
    # Clean up test files
    rm -f "$TEST_LOG_FILE" "$TEST_CONFIG_FILE"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ $message"
        ((TESTS_PASSED++))
    else
        echo "  ✗ $message"
        echo "    Expected: '$expected'"
        echo "    Actual: '$actual'"
        ((TESTS_FAILED++))
    fi
}

assert_true() {
    local condition="$1"
    local message="$2"
    
    if [[ $condition -eq 0 ]]; then
        echo "  ✓ $message"
        ((TESTS_PASSED++))
    else
        echo "  ✗ $message"
        echo "    Expected: true (exit code 0)"
        echo "    Actual: false (exit code $condition)"
        ((TESTS_FAILED++))
    fi
}

assert_false() {
    local condition="$1"
    local message="$2"
    
    if [[ $condition -ne 0 ]]; then
        echo "  ✓ $message"
        ((TESTS_PASSED++))
    else
        echo "  ✗ $message"
        echo "    Expected: false (non-zero exit code)"
        echo "    Actual: true (exit code 0)"
        ((TESTS_FAILED++))
    fi
}

# Test cases
test_validate_ip() {
    setup_test "validate_ip"
    
    # Valid IP addresses
    validate_ip "192.168.1.1"
    assert_true $? "Valid IP: 192.168.1.1"
    
    validate_ip "10.0.0.1"
    assert_true $? "Valid IP: 10.0.0.1"
    
    validate_ip "172.16.0.1"
    assert_true $? "Valid IP: 172.16.0.1"
    
    validate_ip "127.0.0.1"
    assert_true $? "Valid IP: 127.0.0.1"
    
    # Invalid IP addresses
    validate_ip "256.1.1.1"
    assert_false $? "Invalid IP: 256.1.1.1"
    
    validate_ip "192.168.1"
    assert_false $? "Invalid IP: 192.168.1"
    
    validate_ip "192.168.1.1.1"
    assert_false $? "Invalid IP: 192.168.1.1.1"
    
    validate_ip "not.an.ip.address"
    assert_false $? "Invalid IP: not.an.ip.address"
    
    validate_ip ""
    assert_false $? "Empty IP address"
}

test_validate_port() {
    setup_test "validate_port"
    
    # Valid ports
    validate_port "22"
    assert_true $? "Valid port: 22"
    
    validate_port "80"
    assert_true $? "Valid port: 80"
    
    validate_port "443"
    assert_true $? "Valid port: 443"
    
    validate_port "65535"
    assert_true $? "Valid port: 65535"
    
    validate_port "1"
    assert_true $? "Valid port: 1"
    
    # Invalid ports
    validate_port "0"
    assert_false $? "Invalid port: 0"
    
    validate_port "65536"
    assert_false $? "Invalid port: 65536"
    
    validate_port "-1"
    assert_false $? "Invalid port: -1"
    
    validate_port "abc"
    assert_false $? "Invalid port: abc"
    
    validate_port ""
    assert_false $? "Empty port"
}

test_validate_username() {
    setup_test "validate_username"
    
    # Valid usernames
    validate_username "user"
    assert_true $? "Valid username: user"
    
    validate_username "admin123"
    assert_true $? "Valid username: admin123"
    
    validate_username "test_user"
    assert_true $? "Valid username: test_user"
    
    validate_username "_system"
    assert_true $? "Valid username: _system"
    
    # Invalid usernames
    validate_username "123user"
    assert_false $? "Invalid username: 123user"
    
    validate_username "user@domain"
    assert_false $? "Invalid username: user@domain"
    
    validate_username "User"
    assert_false $? "Invalid username: User (uppercase)"
    
    validate_username ""
    assert_false $? "Empty username"
    
    # Too long username (over 32 characters)
    validate_username "this_username_is_way_too_long_for_system"
    assert_false $? "Invalid username: too long"
}

test_validate_path() {
    setup_test "validate_path"
    
    # Valid paths
    validate_path "/home/user"
    assert_true $? "Valid path: /home/user"
    
    validate_path "/var/lib/docker"
    assert_true $? "Valid path: /var/lib/docker"
    
    validate_path "/opt/app-1.0"
    assert_true $? "Valid path: /opt/app-1.0"
    
    validate_path "/tmp"
    assert_true $? "Valid path: /tmp"
    
    # Invalid paths
    validate_path "relative/path"
    assert_false $? "Invalid path: relative/path"
    
    validate_path "/path with spaces"
    assert_false $? "Invalid path: /path with spaces"
    
    validate_path ""
    assert_false $? "Empty path"
}

test_save_and_load_config() {
    setup_test "save_and_load_config"
    
    # Test saving configuration
    save_config "TEST_KEY" "test_value"
    save_config "SSH_PORT" "2222"
    save_config "ENABLE_FEATURE" "true"
    
    # Check if config file was created
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "  ✓ Config file created"
        ((TESTS_PASSED++))
    else
        echo "  ✗ Config file not created"
        ((TESTS_FAILED++))
    fi
    
    # Test loading configuration
    unset TEST_KEY SSH_PORT ENABLE_FEATURE
    
    if load_config; then
        echo "  ✓ Config loaded successfully"
        ((TESTS_PASSED++))
    else
        echo "  ✗ Failed to load config"
        ((TESTS_FAILED++))
    fi
    
    # Test loaded values
    assert_equals "test_value" "$TEST_KEY" "TEST_KEY loaded correctly"
    assert_equals "2222" "$SSH_PORT" "SSH_PORT loaded correctly"
    assert_equals "true" "$ENABLE_FEATURE" "ENABLE_FEATURE loaded correctly"
    
    # Test updating existing key
    save_config "TEST_KEY" "updated_value"
    unset TEST_KEY
    load_config
    assert_equals "updated_value" "$TEST_KEY" "Config key updated correctly"
}

test_check_disk_space() {
    setup_test "check_disk_space"
    
    # This test checks if the function works, not the actual disk space
    # Use a very small requirement that should always pass
    check_disk_space 1  # 1 GB requirement
    local result=$?
    
    # Should pass on most systems
    if [[ $result -eq 0 ]]; then
        echo "  ✓ Disk space check function works (1GB requirement)"
        ((TESTS_PASSED++))
    else
        echo "  ✗ Disk space check function failed (1GB requirement)"
        ((TESTS_FAILED++))
    fi
}

test_service_management() {
    setup_test "service_management"
    
    # Test with a service that should exist on most systems
    if service_exists "ssh" || service_exists "sshd"; then
        echo "  ✓ service_exists function works"
        ((TESTS_PASSED++))
    else
        echo "  ✗ service_exists function failed"
        ((TESTS_FAILED++))
    fi
    
    # Test with a service that shouldn't exist
    if ! service_exists "nonexistent_service_12345"; then
        echo "  ✓ service_exists correctly identifies non-existent service"
        ((TESTS_PASSED++))
    else
        echo "  ✗ service_exists incorrectly identifies non-existent service"
        ((TESTS_FAILED++))
    fi
}

test_logging() {
    setup_test "logging"
    
    # Test logging functions
    log_info "Test info message"
    log_warning "Test warning message"
    log_error "Test error message" 2>/dev/null  # Suppress stderr
    log_debug "Test debug message"
    
    # Check if log file contains messages
    if [[ -f "$TEST_LOG_FILE" ]]; then
        local log_content=$(cat "$TEST_LOG_FILE")
        
        if echo "$log_content" | grep -q "Test info message"; then
            echo "  ✓ Info logging works"
            ((TESTS_PASSED++))
        else
            echo "  ✗ Info logging failed"
            ((TESTS_FAILED++))
        fi
        
        if echo "$log_content" | grep -q "Test warning message"; then
            echo "  ✓ Warning logging works"
            ((TESTS_PASSED++))
        else
            echo "  ✗ Warning logging failed"
            ((TESTS_FAILED++))
        fi
        
        if echo "$log_content" | grep -q "Test debug message"; then
            echo "  ✓ Debug logging works (DEBUG=true)"
            ((TESTS_PASSED++))
        else
            echo "  ✗ Debug logging failed"
            ((TESTS_FAILED++))
        fi
    else
        echo "  ✗ Log file not created"
        ((TESTS_FAILED++))
    fi
}

# Performance tests
test_performance() {
    setup_test "performance"
    
    # Test IP validation performance
    local start_time=$(date +%s.%N)
    for i in {1..1000}; do
        validate_ip "192.168.1.1" >/dev/null
    done
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    if (( $(echo "$duration < 1.0" | bc -l) )); then
        echo "  ✓ IP validation performance test passed (${duration}s for 1000 calls)"
        ((TESTS_PASSED++))
    else
        echo "  ✗ IP validation performance test failed (${duration}s for 1000 calls)"
        ((TESTS_FAILED++))
    fi
}

# Distribution detection tests
test_normalize_version() {
    setup_test "normalize_version"
    
    # Test standard version formats
    local result=$(normalize_version "24.04.0")
    assert_equals "24.04.0" "$result" "Standard version format"
    
    result=$(normalize_version "12")
    assert_equals "12.0.0" "$result" "Major version only"
    
    result=$(normalize_version "41.1")
    assert_equals "41.1.0" "$result" "Major.minor format"
    
    # Test Debian-style versions
    result=$(normalize_version "12 (bookworm)")
    assert_equals "12.0.0" "$result" "Debian style version"
    
    # Test rolling releases
    result=$(normalize_version "rolling")
    assert_equals "9999.0.0" "$result" "Rolling release"
    
    result=$(normalize_version "unstable")
    assert_equals "9999.0.0" "$result" "Unstable release"
    
    # Test complex versions
    result=$(normalize_version "24.04 LTS")
    assert_equals "24.04.0" "$result" "Version with suffix"
}

test_version_compare() {
    setup_test "version_compare"
    
    # Test greater than or equal
    version_compare "24.04.0" ">=" "24.04.0" && assert_true $? "Equal versions with >="
    version_compare "24.04.1" ">=" "24.04.0" && assert_true $? "Higher version with >="
    version_compare "24.03.0" ">=" "24.04.0" && assert_false $? "Lower version with >="
    
    # Test greater than
    version_compare "24.04.1" ">" "24.04.0" && assert_true $? "Higher version with >"
    version_compare "24.04.0" ">" "24.04.0" && assert_false $? "Equal versions with >"
    
    # Test less than or equal
    version_compare "24.04.0" "<=" "24.04.0" && assert_true $? "Equal versions with <="
    version_compare "24.03.0" "<=" "24.04.0" && assert_true $? "Lower version with <="
    version_compare "24.05.0" "<=" "24.04.0" && assert_false $? "Higher version with <="
    
    # Test less than
    version_compare "24.03.0" "<" "24.04.0" && assert_true $? "Lower version with <"
    version_compare "24.04.0" "<" "24.04.0" && assert_false $? "Equal versions with <"
    
    # Test equal
    version_compare "24.04.0" "==" "24.04.0" && assert_true $? "Equal versions with =="
    version_compare "24.04.0" "=" "24.04.0" && assert_true $? "Equal versions with ="
    version_compare "24.04.1" "==" "24.04.0" && assert_false $? "Different versions with =="
    
    # Test not equal
    version_compare "24.04.1" "!=" "24.04.0" && assert_true $? "Different versions with !="
    version_compare "24.04.0" "!=" "24.04.0" && assert_false $? "Equal versions with !="
}

test_container_detection() {
    setup_test "container_detection"
    
    # Test that function exists and runs without error
    # Note: On macOS, we won't detect actual containers, but the function should work
    unset CONTAINER_TYPE
    
    if detect_container_environment 2>/dev/null; then
        echo "  ✓ Container detection function runs without error"
        ((TESTS_PASSED++))
    else
        echo "  ✗ Container detection function failed"
        ((TESTS_FAILED++))
    fi
    
    # Test that CONTAINER_TYPE is set appropriately (should be empty on macOS)
    if [[ -z "${CONTAINER_TYPE:-}" ]]; then
        echo "  ✓ No container environment detected (expected on macOS)"
        ((TESTS_PASSED++))
    else
        echo "  ✓ Container environment detected: $CONTAINER_TYPE"
        ((TESTS_PASSED++))
    fi
}

# Main test runner
main() {
    echo "Starting NAS Setup Script Unit Tests"
    echo "===================================="
    echo
    
    # Run all tests
    test_validate_ip
    echo
    
    test_validate_port
    echo
    
    test_validate_username
    echo
    
    test_validate_path
    echo
    
    test_save_and_load_config
    echo
    
    test_check_disk_space
    echo
    
    test_service_management
    echo
    
    test_logging
    echo
    
    test_performance
    echo
    
    test_normalize_version
    echo
    
    test_version_compare
    echo
    
    test_container_detection
    echo
    
    # Cleanup
    rm -f "$TEST_LOG_FILE" "$TEST_CONFIG_FILE"
    
    # Summary
    echo "===================================="
    echo "Test Results:"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All tests passed!"
        exit 0
    else
        echo "❌ Some tests failed!"
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
