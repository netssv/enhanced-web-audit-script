# Contributing

Thanks for your interest in contributing! Keep it simple.

## Quick Start

```bash
# Fork and clone
git clone https://github.com/netssv/enhanced-web-audit-script.git
cd enhanced-web-audit-script

# Test it works
./auditweb.sh --self-test

# Make changes and test
./auditweb.sh example.com quick
```

## Making Changes

1. **Create a branch**: `git checkout -b feature/your-feature`
2. **Make your changes**: Edit code, add features, fix bugs
3. **Test thoroughly**: Run `./auditweb.sh --self-test` 
4. **Commit**: `git commit -m "brief description"`
5. **Submit PR**: Create a pull request with description

## Code Style

- Use clear function names
- Add comments for complex logic
- Test with multiple websites
- Keep it simple and readable

## Adding Modules

New modules go in `modules/` directory. Follow the existing pattern and source them in the main script.

## Questions?

Open an issue or start a discussion. Keep it simple, keep it working.

Thanks for contributing! 🎉
