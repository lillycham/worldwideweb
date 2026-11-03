/*	NeXT PageLayout panel on NSPageLayout			PageLayout.m
**	=====================================
**	Ported 2026. See PageLayout.h.
*/
#import "PageLayout.h"

//	NSPageLayout takes accessory views through a view controller.
@interface WWWPageLayoutAccessory : NSViewController <NSPrintPanelAccessorizing>
@end

@implementation WWWPageLayoutAccessory
- (NSArray *)localizedSummaryItems	{ return @[]; }
@end

@implementation PageLayout

+ new
{
    static NSMutableDictionary * shared;	/* One per subclass */
    NSString * key = NSStringFromClass(self);
    PageLayout * me;
    if (!shared) shared = [[NSMutableDictionary alloc] init];
    me = [shared objectForKey:key];
    if (!me) {
	me = [[[self alloc] init] autorelease];
	me->ok = [[NSButton alloc] init];
	me->cancel = [[NSButton alloc] init];
	me->width = [[NSTextField alloc] init];
	me->height = [[NSTextField alloc] init];
	me->scale = [[NSTextField alloc] init];
	[shared setObject:me forKey:key];
    }
    return me;
}

- setAccessoryView:aView	{ accessoryView = aView; return self; }
- accessoryView			{ return accessoryView; }

- (int)runModal
{
    NSPageLayout * panel = [NSPageLayout pageLayout];
    NSPrintInfo * pi = [NXApp printInfo];
    int status;
    [self readPrintInfo];
    if (accessoryView) {
	WWWPageLayoutAccessory * c = [[[WWWPageLayoutAccessory alloc] init] autorelease];
	[accessoryView removeFromSuperview];
	[c setView:accessoryView];
	[panel addAccessoryController:c];
    }
    status = (int)[panel runModalWithPrintInfo:pi];
    if (status == NSModalResponseOK) [self writePrintInfo];
    return status;
}

- pickedUnits:sender		{ return self; }
- readPrintInfo			{ return self; }
- writePrintInfo		{ return self; }

//	Cocoa's page layout panel does not let us see its units, so the
//	accessory fields are always in points.
- convertOldFactor:(float *)old newFactor:(float *)new
{
    *old = 1.0;
    *new = 1.0;
    return self;
}

@end

@implementation NSView (NeXTNextText)
- setNextText:anObject		{ [self setNextKeyView:anObject]; return self; }
@end
