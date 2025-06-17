# Contributing to NAS Setup Script v2.0

Thank you for considering contributing to the NAS Setup Script! This project has evolved into a professional-grade tool, and we welcome contributions that maintain this high standard.

## 🎯 Project Vision

Our goal is to provide a **production-ready**, **enterprise-grade** NAS setup solution that follows software engineering best practices while remaining accessible to both novice and expert users.

## 📋 Contribution Guidelines

### 🐛 Reporting Bugs

When reporting bugs, please use our structured issue template:

**Required Information:**
- **Environment:** OS distribution, version, hardware specs
- **Script Version:** Output of `./setup.sh --version`
- **Clear Title:** Descriptive summary of the issue
- **Reproduction Steps:** Detailed steps to reproduce
- **Expected vs Actual Behavior:** What should happen vs what happens
- **Logs:** Relevant excerpts from `/var/log/nas_setup.log`
- **Configuration:** Your `/etc/nas_setup.conf` (sanitized)

**Example:**
```
Title: "Firewall configuration fails on Fedora 37"
Environment: Fedora 37, 4GB RAM, VirtualBox VM
Steps: 1. Run setup.sh, 2. Select all services, 3. Firewall config step fails
Logs: [Include error from log file]
```

### 💡 Suggesting Enhancements

For feature requests, please provide:

- **Use Case:** Real-world scenario for the enhancement
- **Proposed Solution:** Technical approach if applicable
- **Impact Assessment:** Who benefits and how
- **Backward Compatibility:** How it affects existing installations
- **Testing Strategy:** How the feature should be validated

### 🔄 Development Workflow

1. **Fork & Clone**
   ```bash
   git clone https://github.com/YOUR_USERNAME/nas.git
   cd nas
   ```

2. **Create Feature Branch**
   ```bash
   git checkout -b feature/descriptive-name
   # or
   git checkout -b fix/issue-number
   ```

3. **Development Environment Setup**
   ```bash
   # Make scripts executable
   chmod +x setup.sh tests/unit_tests.sh
   
   # Run unit tests
   ./tests/unit_tests.sh
   ```

4. **Make Changes** following our coding standards

5. **Test Thoroughly**
   ```bash
   # Run unit tests
   ./tests/unit_tests.sh
   
   # Test on clean VM/container
   # Verify rollback functionality
   # Test error scenarios
   ```

6. **Commit & Push**
   ```bash
   git add .
   git commit -m "feat: add enhanced firewall monitoring"
   git push origin feature/descriptive-name
   ```

7. **Create Pull Request** with detailed description

## 💻 Code Standards

### Bash Scripting Standards

**Strict Error Handling:**
```bash
#!/bin/bash
set -euo pipefail  # Always use this
```

**Function Documentation:**
```bash
# Function description
# Arguments:
#   $1 - Parameter description
#   $2 - Parameter description  
# Returns:
#   0 - Success
#   1 - Error
function_name() {
    local param1="$1"
    local param2="$2"
    
    # Implementation
}
```

**Error Handling:**
```bash
if ! some_command; then
    log_error "Descriptive error message"
    return 1
fi

# Use handle_error for critical operations
handle_error sudo systemctl start service
```

**Variable Naming:**
```bash
# Constants: UPPER_CASE
readonly SCRIPT_VERSION="2.0.0"

# Global variables: UPPER_CASE  
DISTRO=""
CONFIG_FILE="/etc/nas_setup.conf"

# Local variables: lower_case
local username="$1"
local config_path="/tmp/config"
```

### Input Validation Requirements

**Always validate user input:**
```bash
# Use existing validation functions
local ip=$(ask_input "IP address" "192.168.1.100" "validate_ip")
local port=$(ask_input "Port" "22" "validate_port")
local username=$(ask_input "Username" "admin" "validate_username")
```

**Create new validators when needed:**
```bash
validate_custom_input() {
    local input="$1"
    # Validation logic
    return 0  # or 1 for invalid
}
```

### Security Requirements

**All security-related changes require:**
- Security impact assessment
- Review by maintainer
- Testing in isolated environment
- Documentation of security implications

**Security best practices:**
- Never log sensitive information (passwords, keys)
- Validate all external input
- Use parameterized commands
- Implement principle of least privilege

### Testing Requirements

**Unit Tests for New Functions:**
```bash
test_new_function() {
    setup_test "new_function"
    
    # Test valid inputs
    new_function "valid_input"
    assert_true $? "Valid input should succeed"
    
    # Test invalid inputs  
    new_function "invalid_input"
    assert_false $? "Invalid input should fail"
    
    # Test edge cases
    new_function ""
    assert_false $? "Empty input should fail"
}
```

**Integration Testing:**
- Test on clean VMs for each supported distribution
- Verify rollback functionality works
- Test error scenarios and recovery
- Validate performance doesn't degrade

### Documentation Standards

**Code Comments:**
```bash
# High-level function description
# Complex logic explanation
# Security considerations
# Performance notes
```

**README Updates:**
- Update feature lists
- Add new configuration options
- Update troubleshooting sections
- Include new requirements

**CHANGELOG Updates:**
```markdown
## [2.1.0] - 2025-06-17
### Added
- New feature description
- Another enhancement

### Changed  
- Modified behavior description

### Fixed
- Bug fix description
```

## 🧪 Testing Strategy

### Required Tests Before PR

1. **Unit Tests:** `./tests/unit_tests.sh` must pass
2. **Clean Installation:** Test on fresh VM of each supported distro
3. **Rollback Testing:** Verify rollback works when errors occur  
4. **Performance Testing:** Ensure no performance degradation
5. **Security Testing:** Validate security implications

### Test Environment Setup

**Recommended Testing:**
```bash
# Use VirtualBox/VMware with these distributions:
- Ubuntu 22.04 LTS
- Debian 12  
- Fedora 38
- Arch Linux (current)
- openSUSE Leap 15.5

# Minimum VM specs:
- 2GB RAM
- 20GB disk
- Network access
```

### Continuous Integration

Our CI pipeline runs:
- Unit tests on all supported distributions
- Integration tests with various configurations  
- Security scans
- Performance benchmarks
- Documentation validation

## 🏗️ Architecture Guidelines

### Modular Design

**Library Structure:**
- Each lib file has single responsibility
- Functions are reusable across modules
- Clear interfaces between modules
- Minimal interdependencies

**Configuration Management:**
- All defaults in `config/defaults.sh`
- User config in `/etc/nas_setup.conf`
- Environment-specific overrides supported
- Validation for all configuration values

### Performance Considerations

**Efficiency Requirements:**
- Functions should complete in reasonable time
- Minimize external command calls in loops
- Use appropriate data structures
- Profile performance-critical sections

**Resource Usage:**
- Minimize memory footprint
- Clean up temporary files
- Efficient logging (avoid excessive I/O)
- Respect system resource limits

## 🚀 Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR:** Breaking changes
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes

### Release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in relevant files
- [ ] Security review completed
- [ ] Performance benchmarks acceptable

## 🤝 Community

### Code of Conduct

We follow the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/0/code_of_conduct/).

### Communication

- **GitHub Issues:** Bug reports and feature requests
- **Pull Requests:** Code contributions and reviews
- **Wiki:** Extended documentation and guides

### Recognition

Contributors are recognized in:
- CHANGELOG.md for significant contributions
- README.md acknowledgments
- Git commit history

## 📄 Legal

### License Agreement

By contributing, you agree that your contributions will be licensed under the MIT License.

### Copyright

- Maintain existing copyright notices
- Add your copyright for substantial contributions
- Respect third-party licenses and attributions

---

**Thank you for contributing to the NAS Setup Script!** 

Your efforts help make this tool better for the entire community. 🎉
