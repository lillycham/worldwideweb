# WorldWideWeb for modern macOS

A source port of WorldWideWeb, the first web browser and editor, written by
Tim Berners-Lee at CERN on a NeXT in 1990–92. It builds from TBL's own
Objective-C and C files, changed as little as possible, on top of a small
NeXTSTEP compatibility layer for AppKit.

The original source comes from
[cynthia/WorldWideWeb](https://github.com/cynthia/WorldWideWeb), which
archives the files from the NeXT distribution of version 0.15–0.16.

## Build and run

You need the Xcode command line tools (`xcode-select --install`).

```bash
make
```

```bash
open build/WorldWideWeb.app
```

The home page is TBL's `default.html`. Double-click a link to follow it,
as on the NeXT. Navigate > Back (Command-^) goes back. Some pages still work
on today's web: `http://info.cern.ch/hypertext/WWW/TheProject.html` is the
restored first website, and you can open it with Document > Open given
document address. Pages over `https:` do not work, because the browser
predates TLS.

To see the console trace TBL used, start the app from a terminal with
`WWW_TRACE=1`.

## Test

```bash
make test
```

This runs a headless test. It reads the bundled pages through TBL's HTML
parser, prints the runs of text with their styles and links, and writes each
page back out as HTML. It opens no windows. `build/htmltest` also takes
`http:` addresses.

## Layout

| Path | What |
|------|------|
| `original/` | The original source, untouched |
| `src/` | TBL's files, ported. Every change is marked `Port:` |
| `src/compat/` | The NeXTSTEP compatibility layer |
| `src/WorldWideWeb_nib.m` | The interface from `WorldWideWeb.nib`, rebuilt in code |
| `docs/nib-spec.txt` | Every window, menu and connection in the nib, decoded |
| `tools/` | The nib decoders that made `docs/` and `resources/` |
| `resources/` | Texts extracted from the nib |

See [PORTING.md](PORTING.md) for what changed and why.

## Licence

The original code is Copyright 1990–1995 CERN and MIT, under the W3C/CERN
licence in [NOTICE](NOTICE). The port is under the same terms. This product
includes computer software created and made available by CERN.
