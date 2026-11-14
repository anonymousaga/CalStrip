# [<img src="CalStrip/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="40" align="top"/>](CalStrip/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png) CalStrip

A lightweight macOS utility that strips meeting invite metadata and converts event timestamps to your local timezone before importing `.ics` files into Apple Calendar.

## What It Does

When you open an `.ics` file with CalStrip, it:

1. **Unfolds multi-line properties** so wrapped headers are processed cleanly.
2. **Strips invite and tracking metadata:** removes `ORGANIZER`, `ATTENDEE`, `URL`, `UID`, and `X-MICROSOFT-DISALLOW-COUNTER` lines.
3. **Converts meeting requests to standard events:** changes `METHOD:REQUEST` to `METHOD:PUBLISH` so Apple Calendar imports the event directly without sending RSVPs or treating it as an external invite.
4. **Normalizes timezones:** converts `DTSTART` and `DTEND` values (both UTC `Z` and `TZID` timestamps) into your Mac's current local timezone.
5. **Hands off to Apple Calendar:** writes a temporary cleaned `.ics` file, opens it in Calendar, and quits automatically.

## Requirements

* Mac with Apple Silicon (`arm64`)

## Installation

### Homebrew (Recommended)

```bash
brew tap anonymousaga/tap
brew trust anonymousaga/tap
brew install --cask calstrip
```

### Manual Download

1. Download the latest `CalStrip-v*-darwin-arm64.zip` archive from the [Releases](https://github.com/anonymousaga/CalStrip/releases) page.
2. Unzip the archive and drag `CalStrip.app` into your `/Applications` folder.

## Bypassing macOS Gatekeeper

Because CalStrip is ad-hoc signed rather than notarized with a paid Apple Developer certificate, macOS Gatekeeper will block it on first launch and on updates.

### Remove the Quarantine Attribute in Terminal

Run the following command after moving `CalStrip.app` to `/Applications`:

```bash
xattr -cr /Applications/CalStrip.app
```

## Set CalStrip as the Default App for All `.ics` Files

To have macOS automatically route every `.ics` file through CalStrip when double-clicked:

1. Locate any `.ics` file in **Finder**.
2. Right-click (or `Control`-click) the file and select **Get Info** (or select the file and press `Cmd + I`).
3. Expand the **Open with:** section.
4. Click the dropdown menu and select **CalStrip.app**.
   * *If CalStrip is not listed, select **Other...**, navigate to `/Applications`, choose **CalStrip.app**, and click **Add**.*
5. Click the **Change All...** button directly below the dropdown menu, then click **Continue** when prompted to apply the change to all `.ics` documents.

## Usage

* **Automatic (Default Handler):** Double-click any `.ics` file in Finder (or open an `.ics` attachment from your browser or email client). CalStrip will clean the file, open it in Apple Calendar, and exit immediately.
* **Dock Icon Import:** Add **CalStrip.app** to the Dock, then drag an `.ics` file onto it to convert and import the ics file.
* **Manual Batch Import:** Launch **CalStrip.app** directly from `/Applications` or Spotlight to open a file picker where you can select one or multiple `.ics` files at once.
