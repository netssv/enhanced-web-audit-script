# 🔍 Enhanced Web Audit Script

A comprehensive, modular bash tool for analyzing websites with advanced DNS propagation checking, intelligent compression analysis, performance testing, and geographic intelligence across 16 global servers.

## ✨ Features

### 🌍 DNS Intelligence
- **Global DNS Propagation**: Tests against 16 DNS servers across 6 regions (USA, Global, Switzerland, Russia, China)
- **Geographic Visualization**: Flag emojis and location details for each DNS server
- **Propagation Analysis**: Consistency checking with detailed value distribution
- **DNS Monitoring**: Real-time DNS change tracking with customizable intervals

### 📊 Compression Analysis
- **Smart Page Size Detection**: Analyzes uncompressed vs compressed sizes
- **Compression Effectiveness**: Shows reduction percentages and ratios
- **Multiple Formats**: Detects Gzip, Brotli, and Deflate compression
- **Intelligent Logic**: Different recommendations based on page size

### ⚡ Performance Testing
- **Multi-Request Analysis**: 5-request average with min/max timing
- **Performance Rating**: Excellent/Good/Average/Slow classifications
- **SSL Handshake Timing**: Separate SSL performance analysis
- **DNS Resolution Speed**: Geographic DNS performance testing

### 🏢 Hosting & Technology Detection
- **Provider Identification**: Detects major cloud providers (AWS, Azure, GCP, Cloudflare)
- **Technology Stack**: Identifies web servers, frameworks, CMS platforms
- **Security Headers**: SSL certificate and security configuration analysis
- **HTTP/2 Support**: Modern protocol support detection

### 🏗️ Modular Architecture
- **Clean Separation**: Individual modules for DNS, HTTP, performance, hosting
- **Easy Maintenance**: Modular design for simple updates and debugging
- **Extensible**: Easy to add new features and analysis types
- **Self-Testing**: Built-in validation and dependency checking

## 🚀 Quick Start

### Prerequisites
```bash
# Required tools (auto-checked by script)
dig, curl, whois, bc

# Optional for enhanced features
nslookup, host
```

### Installation
```bash
# Clone the repository
git clone https://github.com/YOUR-USERNAME/enhanced-web-audit-script.git
cd enhanced-web-audit-script

# Make executable
chmod +x auditweb.sh

# Run self-test
./auditweb.sh --self-test
```

### Basic Usage
```bash
# Quick audit (fast, essential checks)
./auditweb.sh example.com quick

# Comprehensive audit (full analysis)
./auditweb.sh https://example.com

# DNS-only analysis
./auditweb.sh --dns-check example.com

# Monitor DNS changes
./auditweb.sh --dns-monitor example.com 60 10
```

## 📋 Usage Examples

### Standard Website Audit
```bash
./auditweb.sh google.com
```
**Output includes:**
- Domain information and age
- DNS propagation across 16 global servers
- Performance benchmarks with ratings
- Compression analysis with size reduction
- Technology stack detection
- Security and optimization recommendations

### Quick Health Check
```bash
./auditweb.sh github.com quick
```
**Perfect for:**
- Quick status checks
- CI/CD pipeline integration
- Monitoring scripts
- Basic performance validation

### DNS Propagation Monitoring
```bash
# Check current DNS propagation
./auditweb.sh --dns-check cloudflare.com

# Monitor DNS changes every 30 seconds for 5 minutes
./auditweb.sh --dns-monitor example.com 30 10
```

## 🏛️ Architecture

### Module Structure
```
auditweb.sh              # Main script and coordination
modules/
├── core.sh             # Core utilities and benchmarking
├── config.sh           # Configuration and validation
├── dns.sh              # DNS analysis and propagation
├── http.sh             # HTTP checks and technology detection
├── performance.sh      # Performance testing and compression
└── hosting.sh          # Provider detection and characteristics
```

### Data Flow
1. **Input Validation** → Domain/URL processing and normalization
2. **Core Setup** → Module loading and environment preparation
3. **Parallel Analysis** → DNS, HTTP, performance testing
4. **Technology Detection** → Server, framework, CMS identification
5. **Report Generation** → Formatted output with recommendations

## 🔧 Configuration

### Environment Variables
```bash
# Custom configuration file
export AUDITWEB_CONFIG="/path/to/custom.conf"

# Timeout settings
export TIMEOUT_DNS=5
export TIMEOUT_HTTP=30

# Custom user agent
export USER_AGENT="CustomAudit/1.0"
```

### Configuration File
Create `sample_auditweb.conf`:
```bash
# DNS Configuration
TIMEOUT_DNS=5
TIMEOUT_HTTP=30
TIMEOUT_SSL=15

# User Agent
USER_AGENT="Enhanced-Audit/2.1"

# Output Options
COLORS_ENABLED=true
VERBOSE_OUTPUT=false
```

## 📊 Sample Output

### Compression Analysis
```
Compression Analysis:
  Uncompressed Size   :     56.1 KB
  Compressed Size     :     13.9 KB
  Compression Type    :   Brotli
  Size Reduction      :     75.1%
  Compression Ratio   :      4.0:1
  ✅ Compression enabled (Brotli)
```

### DNS Propagation
```
Google Primary            [        8.8.8.8] 🇺🇸 USA Mountain View: 142.250.64.142
Cloudflare Primary        [        1.1.1.1] 🌍 Global Anycast: 142.251.16.101
Yandex Primary            [      77.88.8.8] 🇷🇺 Russia Moscow: 209.85.233.139

== Propagation Analysis ==
Responding servers: 16/16
Unique values found: 6
Propagation status: INCONSISTENT
```

### Performance Benchmarks
```
Performance Summary:
  Average Response    :    0.291s
  Fastest Response    :    0.275s
  Slowest Response    :    0.318s
  Performance Rating  : Excellent
```

## 🛠️ Advanced Features

### DNS Monitoring with Alerts
```bash
# Monitor with custom interval and duration
./auditweb.sh --dns-monitor critical-domain.com 15 40

# Output can be piped for alerting
./auditweb.sh --dns-check example.com | grep "INCONSISTENT" && alert-system
```

### Integration Examples
```bash
# CI/CD Pipeline Check
if ./auditweb.sh myapp.com quick | grep -q "✅"; then
    echo "Health check passed"
else
    echo "Health check failed"
    exit 1
fi

# Monitoring Script
./auditweb.sh production-site.com > daily-audit-$(date +%Y%m%d).log
```

### Custom Output Formats
```bash
# JSON output for automation
./auditweb.sh example.com json > audit-results.json

# HTML report generation
./auditweb.sh example.com html > audit-report.html

# Plain text for logging
./auditweb.sh example.com txt > audit.log
```

## 🤝 Contributing

### Development Setup
```bash
# Fork and clone
git clone https://github.com/YOUR-USERNAME/enhanced-web-audit-script.git
cd enhanced-web-audit-script

# Create feature branch
git checkout -b feature/new-analysis

# Test changes
./auditweb.sh --self-test
```

### Adding New Modules
1. Create module in `modules/` directory
2. Follow the established pattern with functions
3. Source the module in main script
4. Add corresponding tests in self-test function
5. Update documentation

### Code Style
- Use descriptive function names
- Add comments for complex logic
- Follow bash best practices
- Include error handling
- Test with various inputs

## 📝 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- **DNS Providers**: Thanks to all public DNS providers for global testing
- **Community**: Inspired by web performance and security communities
- **Contributors**: All contributors who help improve this tool

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/YOUR-USERNAME/enhanced-web-audit-script/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR-USERNAME/enhanced-web-audit-script/discussions)
- **Documentation**: [Wiki](https://github.com/YOUR-USERNAME/enhanced-web-audit-script/wiki)

---

**⭐ Star this repository if it helps you audit and monitor your web infrastructure!**
