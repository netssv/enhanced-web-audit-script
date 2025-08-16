# Security Policy

## Supported Versions

We actively support the following versions of the Enhanced Web Audit Script with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 2.1.x   | :white_check_mark: |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in the Enhanced Web Audit Script, please follow these steps:

### 1. **Do NOT** create a public GitHub issue

Security vulnerabilities should not be disclosed publicly until they have been addressed.

### 2. Contact us privately

Send a detailed report to: [Your security contact email]

Include in your report:
- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Any suggested fixes (if you have them)

### 3. Response Timeline

- **Initial Response**: Within 48 hours
- **Assessment**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: Within 24-48 hours
  - High: Within 1 week
  - Medium: Within 2 weeks
  - Low: Next planned release

### 4. Responsible Disclosure

We follow responsible disclosure practices:
- We'll acknowledge your report within 48 hours
- We'll provide regular updates on our progress
- We'll credit you in our security advisory (unless you prefer anonymity)
- We'll coordinate the public disclosure timing with you

## Security Considerations

### Script Execution Safety

The Enhanced Web Audit Script is designed with security in mind:

- **Input Validation**: All domain inputs are validated before processing
- **Command Injection Prevention**: Proper quoting and sanitization of variables
- **Network Timeouts**: All network operations have reasonable timeouts
- **Error Handling**: Graceful handling of unexpected responses

### Network Security

- **DNS Queries**: Uses trusted public DNS servers
- **HTTP Requests**: Follows redirects safely with limits
- **SSL Verification**: Validates SSL certificates by default
- **User Agent**: Identifies itself clearly in requests

### Data Privacy

- **No Data Storage**: The script doesn't store or transmit audit results
- **Local Execution**: All analysis is performed locally
- **No External APIs**: Doesn't send data to third-party services
- **Minimal Footprint**: Only makes necessary network requests

### Configuration Security

- **Config File Validation**: Configuration inputs are validated
- **Environment Variables**: Secure handling of environment settings
- **File Permissions**: Recommends appropriate file permissions
- **Path Handling**: Safe handling of file paths and directories

## Security Best Practices for Users

### Installation
```bash
# Verify checksums if provided
sha256sum auditweb.sh

# Set appropriate permissions
chmod 755 auditweb.sh
chmod 644 modules/*.sh
```

### Usage
```bash
# Run with restricted permissions when possible
# Avoid running as root unless necessary
# Review configuration files before use
```

### Network Considerations
- The script makes DNS queries to public DNS servers
- HTTP/HTTPS requests are made to target domains
- No persistent connections or data transmission
- All requests include appropriate User-Agent headers

## Common Security Questions

**Q: Does the script execute any remote code?**
A: No, the script only makes standard DNS queries and HTTP requests. It doesn't execute any code downloaded from remote sources.

**Q: What data does the script collect?**
A: The script only analyzes publicly available information about websites (DNS records, HTTP headers, response times). It doesn't collect or store personal data.

**Q: Is it safe to run against internal/private networks?**
A: The script is designed for public websites. For internal networks, ensure you have proper authorization and consider network security policies.

**Q: Can the script be used maliciously?**
A: The script is a passive analysis tool. It doesn't attempt to exploit vulnerabilities or perform any aggressive testing.

## Security Updates

Security updates will be:
- Released as patch versions (e.g., 2.1.1, 2.1.2)
- Documented in CHANGELOG.md with security notices
- Announced in repository releases
- Tagged with security advisory information when applicable

## Third-Party Dependencies

The script relies on standard system tools:
- `curl` - For HTTP requests
- `dig` - For DNS queries  
- `whois` - For domain information
- `bc` - For calculations

These tools should be kept updated through your system's package manager.

---

Thank you for helping keep the Enhanced Web Audit Script secure! 🔒
