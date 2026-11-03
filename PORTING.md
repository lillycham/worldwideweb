# Porting notes

The aim is a faithful port: TBL's files, classes, methods and algorithms,
with only the changes that modern macOS needs. Each change in `src/` has a
`Port:` comment beside it. `git diff 7c94dfc -- src/` shows all of them,
because that commit is the untouched copy of the original files.

## How it fits together

**The compatibility layer** (`src/compat/`) supplies the parts of the
NeXTSTEP 3 API that the code uses: `Object`, `List`, `NXStream`, `Font`,
`Form`, the open and save panels, defaults, alert panels and `PageLayout`.
Shim headers such as `appkit/appkit.h` and `objc/List.h` let TBL's
`#import` lines stay as they were.

**The Text object** needed the most work. NeXT's `Text` kept its characters
in a linked list of text blocks and its formatting in an array of runs, and
`HyperText` works on those structures directly: it splits and merges runs
in `applyStyle:from:to:`, and the HTML parser appends characters and runs
to them in place. `NXText` keeps real runs and text blocks and mirrors them
to an `NSTextStorage`:

- after the user edits the text, it rebuilds the runs and blocks;
- `calcLine` copies the runs and blocks back. On NeXT, `calcLine` recomputed
  the line breaks from the same structures, so `HyperText` already calls it
  after it changes them.

A run's anchor and paragraph style travel as text attributes, so typing
inside a link keeps the link, as `HyperText`'s `keyDown:` workaround did on
NeXT.

**The nib** is a NeXT typedstream that AppKit cannot read.
`tools/nibspec.py` decodes it to `docs/nib-spec.txt`, and
`src/WorldWideWeb_nib.m` builds the same windows, menus and connections in
code. The panels keep their sizes and their places from the top left of the
screen.

## Bugs that the NeXT hid

These parts of the original worked on the NeXT by accident, and fail on a
modern Mac.

- **Byte order.** The 68k NeXT was big-endian, so `tcp.h` and
  `NewsAccess.m` defined `htons()` and `ntohs()` as no-ops, and
  `NewsAccess.m` set the news port without them. On Intel and Apple silicon,
  a connection would go to port 20480 instead of 80.
- **A null pointer in the HTML parser.** `readSGML:` never set `next_style`.
  A page with text before its first style tag read through it. The original
  pages start with `<TITLE>` and `<H1>`, so they never reach that path.
- **Empty documents.** `finish_output()` unlinked and wrote before the first
  text block when a document was empty.
- **Pasted text.** `HTStyleForRun()` assumed that every run has a paragraph
  style. Text pasted from another application has none.
- **`BOOL`.** `HTUtils.h` defined `BOOL` as `char` when it was not a macro.
  In Objective-C now, `BOOL` is a type, so the `#ifndef` could not see it.

## Changes in behaviour

- **HTTP.** TBL's client sent `GET /path` and read the document, which is
  the whole of HTTP/0.9. Servers now pick the site from a `Host:` header,
  so `info.cern.ch` gives its "404 - Not found" page to that request. The
  port sends `GET /path HTTP/1.0` with `Host:`, and skips the response
  header. To send the original request, set `HTTP09`:

  ```bash
  defaults write ch.cern.info.WorldWideWeb HTTP09 YES
  ```

  Both requests end in CR LF, as the HTTP/0.9 specification says. TBL's
  client sent a bare LF, which servers now refuse.
- **Characters.** The NeXT used its own 8-bit character set. Text that is
  valid UTF-8 is now read as UTF-8, and any other byte is read in the NeXT
  set, so the original documents look as they did. Documents are saved as
  UTF-8.
- **Menus.** TBL's main menu was a vertical panel at the top left of the
  NeXT screen. By default the port draws it that way too (`src/NeXTMenu.m`,
  an addition): a NeXT-style panel in his order, whose submenus open beside
  it and tear off when you drag them by the title bar. The menu bar hides
  itself while the app is active. The same menu is also in the menu bar:
  Info, Print, Page layout, Services, Hide and Quit in the application
  menu, and each submenu as a menu of the bar. To use only the menu bar:

  ```bash
  defaults write ch.cern.info.WorldWideWeb NeXTMenu NO
  ```
- **Find.** In the nib, the items of the Find menu have no actions. Here
  they drive the text view's find bar. "Jump to Selection" no longer has
  Command-j, because "Follow link" also uses it.
- **Fonts.** Ohlfs, the NeXT fixed-width screen font, becomes Monaco.
  Helvetica is still Helvetica. Saved style sheets keep the NeXT names.
- **Windows.** AppKit windows have no separate resize bar, so the 9 points
  that `adjustWindow` added for it are gone. NeXT's `windowWillClose:`
  became AppKit's `windowShouldClose:`.
- **Resources.** `appDirectory` is the bundle's `Contents/Resources/`, where
  the bundled pages and style sheets now go.

## Quirks kept on purpose

- In `setupWindow`, `if (i=SLOTS)` is always true, so each new window takes
  the next position in turn and never reuses a free one.
- The style sheet asks for `Helvetica-Bold-Oblique`, which is not a real font
  name, so Heading5 uses the default font, as on the NeXT.
- `disconnectAnchor:` has no braces round its `if`, so it sets every run to
  black.
- The nib has an "Other document" panel that nothing shows, an empty
  "Paste As" menu and an unconnected "(Diagnostics) > Panel" item. The port
  keeps them.

## Not tested yet

- News (NNTP) and FTP access. Both compile, but I have not tested them
  against a server.
- Printing and the page layout panel.
- Editing, linking and saving in the application. The headless test checks
  that the parser and the HTML writer round-trip a page.
