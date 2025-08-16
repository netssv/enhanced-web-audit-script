# 🔍 Enhanced Web Audit Script

A comprehensive bash tool for website analysis with DNS propagation, compression analysis, and performance testing.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0+-brightgreen.svg)](https://www.gnu.org/software/bash/)

## ✨ Features

- **🌍 Global DNS Propagation**: Tests 16 DNS servers across 6 regions with geographic info
- **📊 Smart Compression Analysis**: Shows page sizes and compression effectiveness
- **⚡ Performance Testing**: Response times, ratings, and benchmarks
- **🏗️ Modular Design**: Clean, maintainable architecture

## 🚀 Quick Start

```bash
# Clone and setup
git clone https://github.com/netssv/enhanced-web-audit-script.git
cd enhanced-web-audit-script
chmod +x auditweb.sh

# Quick website check
./auditweb.sh example.com quick

# Full comprehensive audit
./auditweb.sh https://github.com

# DNS propagation only
./auditweb.sh --dns-check cloudflare.com
```

## 📋 Usage Examples

```bash
# Quick health check
./auditweb.sh github.com quick

# Monitor DNS changes
./auditweb.sh --dns-monitor example.com 60 10

# Self-test
./auditweb.sh --self-test
```

## 📊 Sample Output

### Compression Analysis
```
Compression Analysis:
  Uncompressed Size   :     56.1 KB
  Compressed Size     :     13.9 KB
  Compression Type    :   Brotli
  Size Reduction      :     75.1%
  ✅ Compression enabled (Brotli)
```

### DNS Propagation
```
Google Primary     [8.8.8.8] 🇺🇸 USA: 142.250.64.142
Cloudflare Primary [1.1.1.1] 🌍 Global: 142.251.16.101
Yandex Primary     [77.88.8.8] 🇷🇺 Russia: 209.85.233.139

Propagation status: INCONSISTENT (6 unique values)
```

## 🛠️ Requirements

- `bash 4.0+`
- `curl`, `dig`, `whois`, `bc`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Test your changes: `./auditweb.sh --self-test`
4. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📝 License

MIT License - see [LICENSE](LICENSE) file.

---

**⭐ Star this repo if it helps you audit your web infrastructure!**
