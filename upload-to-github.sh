#!/bin/bash

# Simple script to upload Enhanced Web Audit Script to GitHub
# Repository: https://github.com/netssv/enhanced-web-audit-script

echo "🚀 Preparing Enhanced Web Audit Script for GitHub upload..."

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git remote add origin https://github.com/netssv/enhanced-web-audit-script.git
fi

echo "📋 Files to upload:"
echo "✅ auditweb.sh (main script)"
echo "✅ modules/ (DNS, performance, hosting modules)"
echo "✅ README.md (simple documentation)"
echo "✅ CONTRIBUTING.md (contribution guide)"
echo "✅ LICENSE (MIT license)"
echo "✅ SECURITY.md (security policy)"
echo "✅ CHANGELOG.md (version history)"
echo "✅ sample_auditweb.conf (configuration example)"
echo "✅ .gitignore (ignore patterns)"

echo
echo "🔍 Running self-test before upload..."
if ./auditweb.sh --self-test >/dev/null 2>&1; then
    echo "✅ Self-test passed!"
else
    echo "❌ Self-test failed! Please fix issues before upload."
    exit 1
fi

echo
echo "📦 Adding files to git..."
git add .

echo "💾 Creating commit..."
git commit -m "feat: Enhanced Web Audit Script v2.1

- Global DNS propagation across 16 servers with geographic info
- Compression analysis with page size logic and effectiveness metrics  
- Performance testing with detailed benchmarks and ratings
- Modular architecture for maintainability
- Self-testing and validation capabilities

Perfect for DevOps teams and web developers!"

echo
echo "🌐 Ready to push to GitHub!"
echo "Run these commands to upload:"
echo
echo "git branch -M main"
echo "git push -u origin main"
echo
echo "Repository URL: https://github.com/netssv/enhanced-web-audit-script"
echo
echo "✨ Done! Your repository is ready for collaboration!"
