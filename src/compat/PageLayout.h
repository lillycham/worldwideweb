/*	NeXT PageLayout panel on NSPageLayout			PageLayout.h
**	=====================================
**
**	On NeXT, PageLayout was a panel class which applications subclassed to
**	add fields (WWWPageLayout adds the margins). Here it is a small object
**	which runs NSPageLayout, with the subclass's accessory view added.
**	Ported 2026.
*/
#import "NeXTCompat.h"

@interface PageLayout : NSObject
{
    id	accessoryView;
    id	ok;			/* Stand-ins for the NeXT panel's own */
    id	cancel;			/*  controls, which WWWPageLayout's */
    id	width;			/*  outlet methods refer to. */
    id	height;
    id	scale;
}
+ new;				/* The shared panel, as on NeXT */
- setAccessoryView:aView;
- accessoryView;
- (int)runModal;
- pickedUnits:sender;
- readPrintInfo;
- writePrintInfo;
- convertOldFactor:(float *)old newFactor:(float *)new;
@end

@interface NSView (NeXTNextText)
- setNextText:anObject;
@end
