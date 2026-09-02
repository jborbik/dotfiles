#!/usr/bin/env zsh
set -e

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true

# Disable press-and-hold for keys in favor of key repeat.
defaults write -g ApplePressAndHoldEnabled -bool false

# Set a really fast key repeat. -- original = 2, another option 1
defaults write NSGlobalDomain KeyRepeat -int 2
# original 15, another option 10
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

###############################################################################
# General UI/UX                                                               #
###############################################################################

echo "Disabling startup sound effects, password will be required"
# Disable the sound effects on boot
set -x
sudo nvram StartupMute=%01
set +x

# Disable crash report windows
# https://stackoverflow.com/questions/6084497/silencing-osx-crash-report-window
defaults write com.apple.CrashReporter DialogType server

# Dock autohide
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-time-modifier -float 0.15
killall Dock

# Reduce the padding between the elements
# To disable:
# defaults -currentHost delete -globalDomain NSStatusItemSpacing
# defaults -currentHost delete -globalDomain NSStatusItemSelectionPadding
defaults -currentHost write -globalDomain NSStatusItemSpacing -int 14
defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 8

# Disable double space to period substitution
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
# Prevent Safari from opening ‘safe’ files automatically after downloading
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Show status bar in Safari
defaults write com.apple.Safari ShowOverlayStatusBar -bool true
