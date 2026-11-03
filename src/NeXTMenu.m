/*	NeXTSTEP-style menus					NeXTMenu.m
**	====================
**
**	See NeXTMenu.h. Port addition (2026), not part of the original.
**
**	The look follows NeXTSTEP 3: a black title bar with the title in white
**	Helvetica-Bold, then a column of light grey cells, each bevelled
**	(white above and to the left, dark grey and black below and to the
**	right). A submenu cell has an arrow; a cell with a key equivalent shows
**	the key on the right. A pressed cell turns white.
**
**	Behaviour: pressing a submenu cell opens the submenu beside it, and it
**	stays open (attached) until the cell is pressed again. Dragging an
**	attached submenu by its title bar tears it off: it then has a close box.
*/

#import "NeXTMenu.h"

#define TITLE_HEIGHT	21.0
#define ROW_HEIGHT	21.0
#define MIN_WIDTH	110.0
#define PAD		6.0
#define ARROW_SPACE	14.0
#define CLOSE_SIZE	13.0

static NSFont * menuFont(void)		{ return [NSFont fontWithName:@"Helvetica" size:12]; }
static NSFont * titleFont(void)		{ return [NSFont fontWithName:@"Helvetica-Bold" size:12]; }
static NSColor * gray(CGFloat w)	{ return [NSColor colorWithCalibratedWhite:w alpha:1]; }

static NSMutableArray * allPanels;	/* For refreshing the enabled state */


@interface NXMenuPanel : NSPanel
{
@public
    NSArray *		items;		/* NSMenuItems, separators left out */
    NSString *		menuTitle;
    NXMenuPanel *	parentPanel;	/* nil for the main menu */
    NSMutableDictionary * children;	/* Row number -> submenu panel */
    NSInteger		openRow;	/* Row whose submenu is attached, or -1 */
    NSInteger		pressedRow;	/* Row being pressed, or -1 */
    BOOL		tornOff;
}
- initWithTitle:(NSString *)title items:(NSArray *)menuItems parent:(NXMenuPanel *)parent;
- (NSInteger)rowAtPoint:(NSPoint)p;
- (void)closeAttachedSubmenu;
@end

@interface NXMenuView : NSView
@end


@implementation NXMenuPanel

- initWithTitle:(NSString *)title items:(NSArray *)menuItems parent:(NXMenuPanel *)parent
{
    NSMutableArray * kept = [NSMutableArray array];
    CGFloat width = MIN_WIDTH;
    NSDictionary * font = @{ NSFontAttributeName: menuFont() };
    NSRect frame;

    for (NSMenuItem * i in menuItems) {
	CGFloat w;
	if ([i isSeparatorItem] || [i isHidden]) continue;
	[kept addObject:i];
	w = PAD + [[i title] sizeWithAttributes:font].width + PAD;
	if ([[i keyEquivalent] length])
	    w += [[i keyEquivalent] sizeWithAttributes:font].width + 2 * PAD;
	if ([i hasSubmenu]) w += ARROW_SPACE;
	width = MAX(width, ceil(w));
    }
    width = MAX(width, ceil(PAD + [title sizeWithAttributes:@{ NSFontAttributeName: titleFont() }].width
	+ PAD + CLOSE_SIZE + PAD));

    frame = NSMakeRect(0, 0, width, TITLE_HEIGHT + ROW_HEIGHT * [kept count]);
    self = [super initWithContentRect:frame
	styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
	backing:NSBackingStoreBuffered defer:NO];
    if (!self) return nil;
    items = [kept copy];
    menuTitle = [title copy];
    parentPanel = parent;
    children = [[NSMutableDictionary alloc] init];
    openRow = pressedRow = -1;
    [self setLevel:NSFloatingWindowLevel];
    [self setHidesOnDeactivate:YES];
    [self setHasShadow:NO];			/* NeXT windows had none */
    [self setOpaque:YES];
    [self setReleasedWhenClosed:NO];
    [self setContentView:[[[NXMenuView alloc] initWithFrame:frame] autorelease]];
    if (!allPanels) allPanels = [[NSMutableArray alloc] init];
    [allPanels addObject:self];
    return self;
}

- (BOOL)canBecomeKeyWindow	{ return NO; }	/* Leave the key window alone */
- (BOOL)canBecomeMainWindow	{ return NO; }

- (NSInteger)rowAtPoint:(NSPoint)p		/* p in the (flipped) view */
{
    NSInteger row;
    if (p.y < TITLE_HEIGHT || p.x < 0 || p.x >= NSWidth([self frame])) return -1;
    row = (NSInteger)((p.y - TITLE_HEIGHT) / ROW_HEIGHT);
    return row < (NSInteger)[items count] ? row : -1;
}

- (NXMenuPanel *)submenuPanelForRow:(NSInteger)row
{
    NSNumber * key = @(row);
    NXMenuPanel * p = [children objectForKey:key];
    if (!p) {
	NSMenuItem * i = [items objectAtIndex:row];
	p = [[[NXMenuPanel alloc] initWithTitle:[i title]
	    items:[[i submenu] itemArray] parent:self] autorelease];
	[children setObject:p forKey:key];
    }
    return p;
}

- (void)closeAttachedSubmenu
{
    NXMenuPanel * p;
    if (openRow < 0) return;
    p = [children objectForKey:@(openRow)];
    openRow = -1;
    [[self contentView] setNeedsDisplay:YES];
    if (!p || p->tornOff) return;
    [p closeAttachedSubmenu];
    [self removeChildWindow:p];
    [p orderOut:self];
}

//	Open the submenu of a row, beside the row, with its title bar level
//	with the row. A torn-off submenu is just brought to the front.
- (void)openSubmenuForRow:(NSInteger)row
{
    NXMenuPanel * p = [self submenuPanelForRow:row];
    NSRect f = [self frame];
    [self closeAttachedSubmenu];
    if (p->tornOff) {
	[p orderFront:self];
	return;
    }
    [p setFrameTopLeftPoint:NSMakePoint(NSMaxX(f) - 1,
	NSMaxY(f) - TITLE_HEIGHT - ROW_HEIGHT * row)];
    [self addChildWindow:p ordered:NSWindowAbove];
    [p orderFront:self];
    openRow = row;
    [[self contentView] setNeedsDisplay:YES];
}

- (void)tearOff
{
    if (!parentPanel || tornOff) return;
    [parentPanel removeChildWindow:self];
    if (parentPanel->openRow >= 0
    &&  [parentPanel->children objectForKey:@(parentPanel->openRow)] == self) {
	parentPanel->openRow = -1;
	[[parentPanel contentView] setNeedsDisplay:YES];
    }
    tornOff = YES;
    [[self contentView] setNeedsDisplay:YES];
}

- (void)close
{
    [self closeAttachedSubmenu];
    tornOff = NO;
    [super close];
}

@end


@implementation NXMenuView

- (BOOL)isFlipped				{ return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e		{ return YES; }

static NSRect closeBoxRect(NSRect bounds)
{
    return NSMakeRect(NSMaxX(bounds) - PAD - CLOSE_SIZE,
	(TITLE_HEIGHT - CLOSE_SIZE) / 2, CLOSE_SIZE, CLOSE_SIZE);
}

static void bevel(NSRect r, BOOL raised)
{
    [gray(raised ? 1.0 : 0.0) set];		/* Top and left */
    NSRectFill(NSMakeRect(NSMinX(r), NSMinY(r), NSWidth(r), 1));
    NSRectFill(NSMakeRect(NSMinX(r), NSMinY(r), 1, NSHeight(r)));
    [gray(1.0/3.0) set];			/* Inner bottom and right */
    NSRectFill(NSMakeRect(NSMinX(r) + 1, NSMaxY(r) - 2, NSWidth(r) - 2, 1));
    NSRectFill(NSMakeRect(NSMaxX(r) - 2, NSMinY(r) + 1, 1, NSHeight(r) - 2));
    [gray(raised ? 0.0 : 1.0) set];		/* Outer bottom and right */
    NSRectFill(NSMakeRect(NSMinX(r), NSMaxY(r) - 1, NSWidth(r), 1));
    NSRectFill(NSMakeRect(NSMaxX(r) - 1, NSMinY(r), 1, NSHeight(r)));
}

- (void)drawRect:(NSRect)dirty
{
    NXMenuPanel * panel = (NXMenuPanel *)[self window];
    NSRect b = [self bounds];
    NSInteger row = 0;
    NSMutableSet * menus = [NSMutableSet set];

    for (NSMenuItem * i in panel->items) if ([i menu]) [menus addObject:[i menu]];
    for (NSMenu * m in menus) [m update];	/* Refresh the enabled state */

//	Title bar

    [[NSColor blackColor] set];
    NSRectFill(NSMakeRect(0, 0, NSWidth(b), TITLE_HEIGHT));
    [panel->menuTitle drawAtPoint:NSMakePoint(PAD, 3) withAttributes:@{
	NSFontAttributeName: titleFont(),
	NSForegroundColorAttributeName: [NSColor whiteColor] }];
    if (panel->tornOff) {
	NSRect c = closeBoxRect(b);
	NSBezierPath * x = [NSBezierPath bezierPath];
	[gray(2.0/3.0) set];
	NSRectFill(c);
	bevel(c, YES);
	[x moveToPoint:NSMakePoint(NSMinX(c) + 3.5, NSMinY(c) + 3.5)];
	[x lineToPoint:NSMakePoint(NSMaxX(c) - 4.5, NSMaxY(c) - 4.5)];
	[x moveToPoint:NSMakePoint(NSMaxX(c) - 4.5, NSMinY(c) + 3.5)];
	[x lineToPoint:NSMakePoint(NSMinX(c) + 3.5, NSMaxY(c) - 4.5)];
	[[NSColor blackColor] set];
	[x setLineWidth:1.5];
	[x stroke];
    }

//	Cells

    for (NSMenuItem * i in panel->items) {
	NSRect r = NSMakeRect(0, TITLE_HEIGHT + ROW_HEIGHT * row, NSWidth(b), ROW_HEIGHT);
	BOOL lit = (row == panel->pressedRow) || (row == panel->openRow);
	NSColor * ink = [i isEnabled] || [i hasSubmenu] ? [NSColor blackColor] : gray(1.0/3.0);
	NSDictionary * a = @{ NSFontAttributeName: menuFont(),
			      NSForegroundColorAttributeName: ink };
	CGFloat right = NSMaxX(r) - PAD;
	[gray(lit ? 1.0 : 2.0/3.0) set];
	NSRectFill(r);
	bevel(r, YES);
	[[i title] drawAtPoint:NSMakePoint(PAD, NSMinY(r) + 3) withAttributes:a];
	if ([i hasSubmenu]) {			/* The NXmenuArrow */
	    NSBezierPath * t = [NSBezierPath bezierPath];
	    CGFloat mx = right - 3, my = NSMidY(r) - 0.5;
	    [t moveToPoint:NSMakePoint(mx - 6, my - 4.5)];
	    [t lineToPoint:NSMakePoint(mx, my)];
	    [t lineToPoint:NSMakePoint(mx - 6, my + 4.5)];
	    [t closePath];
	    [[NSColor blackColor] set];
	    [t fill];
	    right -= ARROW_SPACE;
	}
	if ([[i keyEquivalent] length]) {
	    NSString * k = [i keyEquivalent];
	    CGFloat w = [k sizeWithAttributes:a].width;
	    [k drawAtPoint:NSMakePoint(right - w, NSMinY(r) + 3) withAttributes:a];
	}
	row++;
    }
    [[NSColor blackColor] set];
    NSFrameRect(b);
}

- (void)mouseDown:(NSEvent *)event
{
    NXMenuPanel * panel = (NXMenuPanel *)[self window];
    NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
    NSInteger row = [panel rowAtPoint:p];
    NSMenuItem * item;

    if (p.y < TITLE_HEIGHT) {			/* Title bar */
	if (panel->tornOff && NSPointInRect(p, closeBoxRect([self bounds]))) {
	    [panel close];
	    return;
	}
	[panel tearOff];			/* Only attached submenus */
	[panel performWindowDragWithEvent:event];
	return;
    }
    if (row < 0) return;
    item = [panel->items objectAtIndex:row];

    if ([item hasSubmenu]) {			/* Toggle the submenu */
	if (panel->openRow == row) [panel closeAttachedSubmenu];
	else [panel openSubmenuForRow:row];
	return;
    }
    if (![item isEnabled]) return;

//	Track the press: the cell is lit while the mouse is over it, and the
//	command runs if the button comes up there.

    panel->pressedRow = row;
    [self setNeedsDisplay:YES];
    for (;;) {
	NSEvent * e = [panel nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp];
	NSPoint q = [self convertPoint:[e locationInWindow] fromView:nil];
	NSInteger over = [panel rowAtPoint:q];
	panel->pressedRow = (over == row) ? row : -1;
	[self display];
	if ([e type] == NSEventTypeLeftMouseUp) break;
    }
    if (panel->pressedRow == row) {
	panel->pressedRow = -1;
	[self display];
	[NSApp sendAction:[item action] to:[item target] from:item];
    }
    panel->pressedRow = -1;
    [self setNeedsDisplay:YES];
}

@end


//	Keep the enabled state of the cells current, as the main window and
//	its selection change.
@interface NXMenuRefresher : NSObject
@end

@implementation NXMenuRefresher
+ (void)refresh:(NSTimer *)t
{
    for (NXMenuPanel * p in allPanels)
	if ([p isVisible]) [[p contentView] setNeedsDisplay:YES];
}
+ (void)hideMenuBar:(NSNotification *)n
{
    [NSApp setPresentationOptions:NSApplicationPresentationAutoHideMenuBar];
}
@end


void NXMenuShowMain(NSString * title, NSArray * items)
{
    NXMenuPanel * main = [[NXMenuPanel alloc] initWithTitle:title items:items parent:nil];
    NSRect screen = [[NSScreen mainScreen] frame];
    [main setFrameTopLeftPoint:NSMakePoint(NSMinX(screen), NSMaxY(screen))];
    [main orderFront:nil];
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:[NXMenuRefresher class]
	selector:@selector(refresh:) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:[NXMenuRefresher class]
	selector:@selector(hideMenuBar:) name:NSApplicationDidBecomeActiveNotification object:nil];
}
