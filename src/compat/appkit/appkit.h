/*	Shim for the NeXTSTEP header <appkit/appkit.h>.
**	See NeXTCompat.h.
**
**	Mac file systems ignore case, so this file is also what the compiler
**	finds for <AppKit/AppKit.h> when NeXTCompat.h imports Cocoa. In that
**	case we pass the request on to the real AppKit.
*/
#ifdef NEXTCOMPAT_H
#include_next <AppKit/AppKit.h>
#else
#import "NeXTCompat.h"
#endif
