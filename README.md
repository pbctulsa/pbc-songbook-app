# PBC Songbook for iOS

Native SwiftUI songbook for Peniel Baptist Church, Tulsa. Built from the approved navy/red mockups, using native navigation and real church song data.

## Open and run

1. Open `PBCSongbook.xcodeproj` in **Xcode 26 or later** on a Mac.
2. Select the **PBCSongbook** scheme and an iPhone simulator, then Run.
3. To install on your phone, choose your Apple development team under Signing & Capabilities and connect your iPhone. Change the bundle identifier if your team requires it.

Minimum OS: **iOS 17**. Native tab bars adopt **Liquid Glass on iOS 26**. The reading toolbar uses the system glass effect on iOS 26 and material on earlier versions, with a solid accessibility fallback. iPhone and iPad are supported. There are no third-party app dependencies.

## Included

- 1,171 published church songs bundled for offline use on first launch; captured September 13, 2026.
- Search across title, number, lyrics, and collection. Collection filter distinguishes repeated numbers in different books.
- Favorites saved on the device.
- Large selectable lyrics, Dynamic Type, reader size controls, system/light/sepia/dark appearance, and optional keep-awake while the reader is active.
- Copy title/number and formatted lyrics; native sharing of lyrics or the public song URL.
- Complete catalog updates validated before atomic replacement. Failed updates preserve the last usable catalog.
- Optional Wi-Fi updates while the app is open; manual updates may use mobile data. This is not background scheduling.
- Suggested edits use the existing review endpoint. Full original fields are retained with the proposed corrections. Drafts persist locally and can be reopened from Downloads.
- About & Support from the info icon; church branding, James's credit, confirmed Church Center giving URL, contact and privacy information.

## Backend

The app uses existing public endpoints; no database credentials or API secrets are bundled:

- `GET https://www.pbctulsa.org/api/songs`
- `POST https://www.pbctulsa.org/api/song-edit-suggestions`
- Giving: `https://pbctulsa.churchcenter.com/giving`

Contract verified against `pbctulsa/pbc-website` main at `b60e8a0af3c56ccc3fc98ccc1f7f92d4d8928c05`. The published GET endpoint returned 1,171 songs during development. No test suggestions were sent to the live review queue.

The existing suggestion API has no idempotency key. The app prevents concurrent submissions and warns about uncertain timeout results rather than automatically retrying. It does not auto-submit saved drafts. Review management remains in the existing church backend; an admin app is outside this client.

## Validation

`PBCSongbookTests` covers decoding API aliases, rejecting incomplete/duplicate catalogs, search, sorting shared song numbers, share formatting, suggestion payloads, and the bundled catalog. GitHub Actions builds and runs these tests with Xcode 26 on macOS.

The development workspace is Linux and has no Xcode, Swift compiler, or iOS simulator. A simulator build and visual/device verification are required before claiming release readiness. Check the latest Actions run for current build results.

Manual checks before TestFlight:

- Launch in airplane mode; search and open a song from every collection.
- Favorite a song, change reading preferences, restart, and confirm persistence.
- Update successfully, then try with no network; confirm all saved lyrics remain.
- Copy and share lyrics/link; verify formatting in another app.
- Save a correction offline, restart, reopen from Downloads, and submit an authorized real correction; verify pending review.
- Check iPhone/iPad, landscape, large Dynamic Type, VoiceOver, Reduce Transparency, dark mode, and reader idle timer restoration.
- Verify Church Center giving, credits, lyric reproduction permissions, and privacy text with church leadership. Review App Store privacy answers and donation requirements against actual release behavior.

## Maintaining the project

Run `python3 scripts/generate_project.py` after adding Swift files; the checked-in project and shared scheme are deterministic. Update the bundled catalog with `python3 scripts/update_catalog.py`. This requires network access but no credentials and never changes the server.

The supplied church logo is used directly, with transparent outer whitespace trimmed. App icon is a white-backed version of that asset. No AI-generated UI images are shipped as app screens.
