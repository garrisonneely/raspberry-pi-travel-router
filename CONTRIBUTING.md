# Contributing to Raspberry Pi Travel VPN Router

Thank you for your interest in contributing! This project is open source and welcomes contributions from the community.

## How to Contribute

### Reporting Issues

If you encounter problems or have suggestions:

1. **Check existing issues** first to avoid duplicates
2. **Provide detailed information**:
   - Raspberry Pi model and RAM
   - Raspberry Pi OS version (`cat /etc/os-release`)
   - WiFi adapter model
   - VPN provider (if not NordVPN)
   - Error messages and logs
   - Steps to reproduce

3. **Use the issue templates** when available

### Suggesting Enhancements

We welcome ideas for improvements:

- New features
- Performance optimizations
- Better documentation
- Additional VPN provider support
- Alternative WiFi adapter support
- UI/UX improvements

## Development

### Setting Up Development Environment

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/raspberry-pi-travel-router.git
   cd raspberry-pi-travel-router
   ```

3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Code Style

#### Bash Scripts

- Use 4 spaces for indentation
- Include descriptive comments
- Add error handling with `set -e` or explicit checks
- Use meaningful variable names (UPPER_CASE for constants)
- Add logging with colored output for user feedback
- Test on actual Raspberry Pi hardware

#### Documentation

- Use clear, concise language
- Include code examples where applicable
- Update relevant documentation when changing features
- Check for spelling and grammar
- Use proper Markdown formatting

### Testing

Before submitting:

1. **Test on Raspberry Pi 4** (real hardware preferred)
2. **Verify all services start** correctly
3. **Test VPN connection** and routing
4. **Check documentation** is accurate
5. **Verify scripts** handle errors gracefully

### Submitting Changes

1. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Brief description of changes"
   ```

2. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request**:
   - Use a descriptive title
   - Explain what changes you made and why
   - Reference any related issues
   - Include testing details

## Areas for Contribution

### High Priority

- [ ] Support for additional VPN providers (Mullvad, ExpressVPN, etc.)
- [ ] WireGuard protocol support
- [ ] Web-based configuration interface
- [ ] Automated testing framework
- [ ] Additional WiFi adapter drivers

### Documentation

- [ ] Video tutorials
- [ ] Troubleshooting for specific scenarios
- [ ] Translations to other languages
- [ ] Diagrams and illustrations
- [ ] FAQ expansion

### Features

- [ ] Automatic VPN failover
- [ ] Speed-based server selection
- [ ] Traffic monitoring and statistics
- [ ] Mobile app for management
- [ ] QoS configuration
- [ ] Guest network support
- [ ] Captive portal detection and handling

### Testing & Quality

- [ ] Automated testing scripts
- [ ] Performance benchmarking
- [ ] Security audit
- [ ] Installation testing on different Pi models
- [ ] Compatibility testing with various routers

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Accept constructive criticism
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or inflammatory comments
- Personal or political attacks
- Publishing others' private information

## Questions?

- **General questions**: Open a discussion on GitHub
- **Bug reports**: Create an issue
- **Security issues**: Contact maintainers privately

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Thanked in project documentation

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Getting Help

If you need help with contributions:

1. Read the documentation thoroughly
2. Check existing issues and discussions
3. Ask questions in GitHub Discussions
4. Be specific about what you're trying to accomplish

## Development Best Practices

### Script Development

```bash
# Always include shebang
#!/bin/bash

# Set error handling
set -e  # Exit on error

# Use functions for reusability
function do_something() {
    local param="$1"
    # Implementation
}

# Add logging
log_info "Starting process..."

# Include error checking
if [ ! -f "$FILE" ]; then
    log_error "File not found: $FILE"
    exit 1
fi
```

### Documentation Updates

When changing functionality:

1. Update README.md if user-facing
2. Update relevant docs/ files
3. Update CHANGELOG.md
4. Add to QUICK_REFERENCE.md if applicable
5. Update SETUP_CHECKLIST.md if process changes

### Commit Messages

Use clear, descriptive commit messages:

```
Add support for Mullvad VPN

- Add Mullvad configuration templates
- Update install script for provider selection
- Add documentation for Mullvad setup
- Test on Raspberry Pi 4

Closes #123
```

### Pull Request Template

When creating a PR, include:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

## Testing
- [ ] Tested on Raspberry Pi 4
- [ ] All services start correctly
- [ ] VPN connection verified
- [ ] Documentation updated

## Checklist
- [ ] Code follows project style
- [ ] Comments added where needed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
```

## Versioning

We use Semantic Versioning (SemVer):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

## Release Process

1. Update CHANGELOG.md
2. Update version in relevant files
3. Create release branch
4. Test thoroughly
5. Merge to main
6. Tag release
7. Create GitHub release with notes

---

**Thank you for contributing to make travel networking more secure for everyone!** 🎉
