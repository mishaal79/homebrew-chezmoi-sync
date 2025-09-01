# Homebrew Tap for Chezmoi-Sync

This is the official Homebrew tap for [chezmoi-sync](https://github.com/mishaal79/chezmoi-sync), an automated dotfiles synchronization tool for multiple machines.

## Installation

```bash
# Add the tap
brew tap mishaal79/chezmoi-sync

# Install chezmoi-sync
brew install chezmoi-sync

# Start the services
brew services start chezmoi-sync       # Push service (file watching)
brew services start chezmoi-sync-pull   # Pull service (periodic sync)
```

## Quick Start

After installation:

1. **Check status:**
   ```bash
   chezmoi-sync status
   ```

2. **Manage services:**
   ```bash
   chezmoi-sync start    # Start both services
   chezmoi-sync stop     # Stop both services
   chezmoi-sync restart  # Restart both services
   ```

3. **Development mode:**
   ```bash
   chezmoi-sync dev-mode on   # Disable auto-sync during development
   chezmoi-sync dev-mode off  # Re-enable auto-sync
   ```

## What It Does

Chezmoi-sync provides:
- **Automatic push**: Monitors your chezmoi source directory and pushes changes immediately
- **Automatic pull**: Pulls updates from your remote repository every 5 minutes
- **Machine awareness**: Creates machine-specific branches (auto-sync/[machine-name])
- **Conflict prevention**: Prevents conflicts when editing dotfiles across multiple machines
- **Development mode**: Temporarily disable sync during feature development

## Architecture

The formula installs two services:

1. **Push Service** (`com.chezmoi.sync.push`)
   - Uses macOS `WatchPaths` to monitor `~/.local/share/chezmoi`
   - Triggers immediately when files change
   - Pushes to machine-specific branch

2. **Pull Service** (`com.chezmoi.sync.pull`)
   - Runs every 5 minutes via `StartInterval`
   - Pulls updates from remote repository
   - Applies changes safely with validation

## Configuration

Configuration file: `/opt/homebrew/etc/chezmoi-sync/chezmoi-sync.conf`

Machine ID stored at: `/opt/homebrew/var/lib/chezmoi-sync/machine-id`

Logs stored at: `/opt/homebrew/var/log/chezmoi-sync/`

## Upgrading

```bash
brew update
brew upgrade chezmoi-sync
brew services restart chezmoi-sync
brew services restart chezmoi-sync-pull
```

## Migration from Manual Installation

If you previously installed chezmoi-sync manually, the formula will automatically:
1. Detect your existing machine ID
2. Migrate it to the Homebrew location
3. Clean up old LaunchAgents
4. Preserve your configuration

## Troubleshooting

### Check service status
```bash
brew services list | grep chezmoi-sync
```

### View logs
```bash
tail -f /opt/homebrew/var/log/chezmoi-sync/push.log
tail -f /opt/homebrew/var/log/chezmoi-sync/pull.log
```

### Reset machine ID
```bash
rm /opt/homebrew/var/lib/chezmoi-sync/machine-id
brew services restart chezmoi-sync
```

### Uninstall completely
```bash
brew services stop chezmoi-sync
brew services stop chezmoi-sync-pull
brew uninstall chezmoi-sync
brew untap mishaal79/chezmoi-sync
```

## Requirements

- macOS 12+ (Monterey or later)
- [chezmoi](https://www.chezmoi.io/) installed and initialized
- Git repository configured for chezmoi source
- GitHub SSH keys configured (recommended)

## Formula Details

- **Dependencies**: chezmoi, jq
- **Services**: 2 (push and pull)
- **License**: MIT
- **Homepage**: https://github.com/mishaal79/chezmoi-sync

## Development

To contribute to this tap:

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Run tests: `brew audit --strict chezmoi-sync`
5. Submit a pull request

## Support

For issues with:
- **The formula**: Open an issue in this repository
- **Chezmoi-sync itself**: Open an issue at [mishaal79/chezmoi-sync](https://github.com/mishaal79/chezmoi-sync)

## License

MIT License - see the [main repository](https://github.com/mishaal79/chezmoi-sync) for details.