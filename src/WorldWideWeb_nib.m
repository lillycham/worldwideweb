/*	The WorldWideWeb.nib, rebuilt in code			WorldWideWeb_nib.m
**	======================================
**
**	TBL built the interface in the NeXT Interface Builder, which saved it as
**	a NeXT typedstream (original/.../WorldWideWeb.nib/data.nib). AppKit
**	cannot read that format, so this file makes the same objects in code:
**	the same panels at the same places with the same sizes, the same
**	menus with the same key equivalents, and the same outlet and action
**	connections.
**
**	The layout comes from docs/nib-spec.txt, which tools/nibspec.py
**	decodes from the original nib. The longer help texts are read from
**	NibTexts.plist and Info.rtf, which tools/nibtexts.py and tools/nibrtf.py
**	extract from it.
**
**	Ported 2026. The original design is Copyright 1990-1995 CERN and MIT;
**	see NOTICE in the top directory.
*/

#import "HyperManager.h"
#import "FileAccess.h"
#import "TcpAccess.h"
#import "NewsAccess.h"
#import "TextToy.h"
#import "StyleToy.h"
#import "WWWPageLayout.h"
#import "HTUtils.h"
#import "NeXTMenu.h"

extern int WWW_TraceFlag;


//			Placing things
//			==============
//
//	The NeXT screen was 1120 by 832 points, with its origin at the bottom
//	left, as in AppKit. Panels are placed at the same distance from the
//	top left of the screen as they were on the NeXT, where the menu was.

#define NEXT_SCREEN_HEIGHT 832.0

static NSRect contentRect(CGFloat x, CGFloat y, CGFloat w, CGFloat h)
{
    NSRect screen = [[NSScreen mainScreen] visibleFrame];
    return NSMakeRect(NSMinX(screen) + x,
		      NSMaxY(screen) - (NEXT_SCREEN_HEIGHT - y), w, h);
}

static NSFont * helvetica(CGFloat size)
{
    return [NSFont fontWithName:@"Helvetica" size:size];
}

static NSFont * helveticaBold(CGFloat size)
{
    return [NSFont fontWithName:@"Helvetica-Bold" size:size];
}

static NSPanel * makePanel(NSString * title, CGFloat x, CGFloat y, CGFloat w, CGFloat h)
{
    NSPanel * p = [[NSPanel alloc] initWithContentRect:contentRect(x, y, w, h)
	styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
	backing:NSBackingStoreBuffered defer:YES];
    [p setTitle:title];
    [p setReleasedWhenClosed:NO];
    [p setHidesOnDeactivate:YES];		/* NeXT panels did */
    [p setBecomesKeyOnlyIfNeeded:NO];
    return p;
}

static NSTextField * label(NSView * in, NSString * text, NSRect frame, NSFont * font)
{
    NSTextField * t = [NSTextField wrappingLabelWithString:text ? text : @""];
    [t setFrame:frame];
    [t setFont:font];
    [t setSelectable:NO];
    [in addSubview:t];
    return t;
}

static NSButton * button(NSView * in, NSString * title, NSRect frame, NSFont * font,
	id target, SEL action)
{
    NSButton * b = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [b setTitle:title];
    [b setFont:font];
    [b setBezelStyle:NSBezelStyleSmallSquare];	/* Square, like the NeXT's */
    [b setTarget:target];
    [b setAction:action];
    [in addSubview:b];
    return b;
}

static Form * form(NSView * in, NSArray * titles, NSRect frame)
{
    Form * f = [[[Form alloc] initWithFrame:frame mode:NSTrackModeMatrix
	cellClass:[NSFormCell class] numberOfRows:0 numberOfColumns:1] autorelease];
    CGFloat rowHeight = frame.size.height / [titles count];
    for (NSString * t in titles) [f addEntry:t];
    [f setCellSize:NSMakeSize(frame.size.width, rowHeight - 2)];
    [f setIntercellSpacing:NSMakeSize(0, 2)];
    [f setTitleFont:helvetica(12)];
    [f setTextFont:helvetica(12)];
    [f setAutosizesCells:YES];
    [f setFrame:frame];
    [in addSubview:f];
    return f;
}

static NSBox * box(NSView * in, NSString * title, NSRect frame)
{
    NSBox * b = [[[NSBox alloc] initWithFrame:frame] autorelease];
    [b setTitle:title ? title : @""];
    [b setTitlePosition:title ? NSAtTop : NSNoTitle];
    [b setTitleFont:helvetica(12)];
    [b setContentViewMargins:NSMakeSize(7, 7)];
    [in addSubview:b];
    return b;
}

static NSString * nibText(NSString * window, NSUInteger index)
{
    static NSDictionary * texts;
    if (!texts) texts = [[NSDictionary alloc] initWithContentsOfFile:
	[[NSBundle mainBundle] pathForResource:@"NibTexts" ofType:@"plist"]];
    NSArray * a = [texts objectForKey:window];
    return index < [a count] ? [a objectAtIndex:index] : @"";
}

static NSMenuItem * item(NSMenu * menu, NSString * title, NSString * key,
	id target, SEL action)
{
    NSMenuItem * i = [menu addItemWithTitle:title action:action
	keyEquivalent:key ? key : @""];
    [i setTarget:target];
    return i;
}

static NSMenu * submenu(NSMenu * menu, NSString * title)
{
    NSMenuItem * i = [menu addItemWithTitle:title action:NULL keyEquivalent:@""];
    NSMenu * m = [[[NSMenu alloc] initWithTitle:title] autorelease];
    [i setSubmenu:m];
    return m;
}


//			The application delegate
//			========================
//
//	In the nib, the HyperManager is the Application's delegate. It answers
//	the NeXT delegate messages (appDidInit: and so on), so this object
//	passes the AppKit ones on to it.

@interface WWWApplicationDelegate : NSObject <NSApplicationDelegate>
{
@public
    HyperManager * manager;
}
@end

@implementation WWWApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [manager appDidInit:NSApp];
}

- (BOOL)application:(NSApplication *)app openFile:(NSString *)filename
{
    return [manager appOpenFile:[filename fileSystemRepresentation] type:
	[[filename pathExtension] UTF8String]] != 0;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
    return NO;					/* As on NeXT */
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return YES;
}

@end


//			Load the "nib"
//			==============

void WWWLoadMainNib(void)
{
    HyperManager *	hyperManager;
    FileAccess *	fileAccess;
    TcpAccess *		tcpAccess;
    NewsAccess *	newsAccess;
    TextToy *		textToy;
    StyleToy *		styleToy;
    WWWPageLayout *	pageLayout;
    WWWApplicationDelegate * appDelegate;

    NSWindow * accessories;
    NSPanel * navHelp, * newDocHelp, * info, * styleEditor, * navigation;
    NSPanel * otherDocument, * linksHelp, * inspector, * indexSearch;
    NSView * v;
    NSBox * b;
    Form * f, * f2;
    NSButton * bt;
    NSTextField * t;

//	The custom objects, created with +new as Interface Builder did.

    hyperManager = [HyperManager new];
    fileAccess = [FileAccess new];
    tcpAccess = [TcpAccess new];
    newsAccess = [NewsAccess new];
    textToy = [TextToy new];
    styleToy = [StyleToy new];
    pageLayout = [WWWPageLayout new];
    appDelegate = [[WWWApplicationDelegate alloc] init];
    appDelegate->manager = hyperManager;
    [NSApp setDelegate:appDelegate];


//	Window "Accessories" (never shown: it holds views for other panels)

    accessories = [[NSWindow alloc] initWithContentRect:contentRect(153, 590, 235, 166)
	styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
    [accessories setTitle:@"Accessories"];
    [accessories setReleasedWhenClosed:NO];
    v = [accessories contentView];
    b = box(v, nil, NSMakeRect(12, 86, 202, 71));
    {
	NSButtonCell * proto = [[[NSButtonCell alloc] init] autorelease];
	NSMatrix * m;
	[proto setButtonType:NSButtonTypeRadio];
	[proto setFont:helvetica(12)];
	m = [[[NSMatrix alloc] initWithFrame:NSMakeRect(109, 2, 79, 53)
	    mode:NSRadioModeMatrix prototype:proto numberOfRows:3 numberOfColumns:1] autorelease];
	[[m cellAtRow:0 column:0] setTitle:@"HyperText"];
	[[m cellAtRow:1 column:0] setTitle:@"Rich Text"];
	[[m cellAtRow:2 column:0] setTitle:@"Plain Text"];
	[m sizeToCells];
	[[b contentView] addSubview:m];
	label([b contentView], @"Save file as:", NSMakeRect(0, 20, 110, 21), helvetica(18));
    }
    b = box(v, @"Margins on Paper", NSMakeRect(8, 15, 213, 68));
    f = form([b contentView], @[@"Left:", @"Right:"], NSMakeRect(0, 0, 93, 45));
    f2 = form([b contentView], @[@"Top:", @"Bottom:"], NSMakeRect(96, 0, 103, 45));
    [f setNextText:f2];
    [pageLayout setAccessoryView:b];
    [pageLayout setLeftMargin:[f cellAtIndex:0]];
    [pageLayout setRightMargin:[f cellAtIndex:1]];
    [pageLayout setTopMargin:[f2 cellAtIndex:0]];
    [pageLayout setBottomMargin:[f2 cellAtIndex:1]];
    [pageLayout setSideForm:f];
    [pageLayout setTopBotForm:f2];


//	Panel "Using the navigation Commands"

    navHelp = makePanel(@"Using the navigation Commands", 286, 5, 376, 264);
    label([navHelp contentView], nibText(@"Using the navigation Commands", 0),
	NSMakeRect(13, 16, 347, 240), helvetica(12));


//	Panel "Making a new Document"

    newDocHelp = makePanel(@"Making a new Document", 296, 422, 376, 227);
    v = [newDocHelp contentView];
    label(v, nibText(@"Making a new Document", 0), NSMakeRect(23, 51, 325, 165), helvetica(12));
    label(v, @"See also:", NSMakeRect(30, 20, 58, 15), helvetica(12));


//	Panel "Making links"

    linksHelp = makePanel(@"Making links", 330, 339, 376, 282);
    v = [linksHelp contentView];
    label(v, nibText(@"Making links", 0), NSMakeRect(16, 27, 343, 240), helvetica(12));
    label(v, @"See also:", NSMakeRect(26, 14, 58, 15), helvetica(12));
    button(v, @"Making a new document", NSMakeRect(88, 9, 148, 24), helvetica(12),
	newDocHelp, @selector(makeKeyAndOrderFront:));
    button([newDocHelp contentView], @"Making links", NSMakeRect(93, 13, 81, 24), helvetica(12),
	linksHelp, @selector(makeKeyAndOrderFront:));


//	Panel "Info"

    info = makePanel(@"Info", 337, 339, 472, 448);
    v = [info contentView];
    label(v, @"HyperMedia Browser/Editor", NSMakeRect(122, 415, 236, 21), helvetica(18));
    label(v, @" Version 0.15\nBeta only", NSMakeRect(379, 410, 93, 26), helvetica(10));
    label(v, @"by Tim Berners-Lee", NSMakeRect(332, 349, 133, 18), helvetica(14));
    label(v, @"Copyright 1990,91, CERN.   Distribution restricted: ask for terms.  TEST VERSION ONLY",
	NSMakeRect(10, 328, 432, 13), helvetica(10));
    b = [[[NSBox alloc] initWithFrame:NSMakeRect(2, 344, 470, 2)] autorelease];
    [b setBoxType:NSBoxSeparator];
    [v addSubview:b];
    label(v, @"An excercise in global information availability",
	NSMakeRect(121, 367, 208, 36), helvetica(14));
    label(v, nibText(@"Info", 1), NSMakeRect(5, 281, 463, 36), helvetica(14));
    {
	NSScrollView * sv = [[[NSScrollView alloc] initWithFrame:NSMakeRect(25, 27, 418, 231)] autorelease];
	NSTextView * tv = [[[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 395, 227)] autorelease];
	NSData * rtf = [NSData dataWithContentsOfFile:
	    [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"rtf"]];
	[sv setBorderType:NSBezelBorder];
	[sv setHasVerticalScroller:YES];
	[sv setScrollerStyle:NSScrollerStyleLegacy];
	[tv setAutoresizingMask:NSViewWidthSizable];
	if (rtf) [tv replaceCharactersInRange:NSMakeRange(0, 0) withRTF:rtf];
	[tv setEditable:NO];
	[sv setDocumentView:tv];
	[v addSubview:sv];
    }


//	Panel "Style editor"

    styleEditor = makePanel(@"Style editor", 2, 1, 342, 406);
    v = [styleEditor contentView];
    button(v, @"Apply style to selection", NSMakeRect(4, 293, 166, 40), helveticaBold(12),
	styleToy, @selector(ApplyButton:));
    button(v, @"Find unstyled text", NSMakeRect(4, 228, 168, 24), helvetica(12),
	styleToy, @selector(FindUnstyledButton:));
    button(v, @"Apply style to all similar text", NSMakeRect(4, 262, 167, 24), helvetica(12),
	styleToy, @selector(ApplyToSimilar:));
    button(v, @"style of selection", NSMakeRect(120, 342, 105, 24), helvetica(12),
	styleToy, @selector(PickButton:));
    button(v, @">>", NSMakeRect(232, 342, 56, 24), helvetica(12),
	styleToy, @selector(NextButton:));
    button(v, @"<<", NSMakeRect(56, 342, 56, 24), helvetica(12),
	styleToy, @selector(PreviousButton:));
    [styleToy setNameForm:form(v, @[@"Style name:"], NSMakeRect(8, 374, 283, 21))];
    box(v, @"Style sheet", NSMakeRect(208, 242, 104, 80));
    button(v, @"Open", NSMakeRect(226, 281, 72, 24), helvetica(12),
	styleToy, @selector(open:));
    button(v, @"Save as...", NSMakeRect(226, 252, 72, 24), helvetica(12),
	styleToy, @selector(saveAs:));
    b = box(v, @"Format", NSMakeRect(1, 14, 324, 209));
    f = form([b contentView], @[@"First line indent:", @"Successive indent:", @"Font:",
	@"Point Size:", @"SGML tag:"], NSMakeRect(0, 59, 216, 127));
    f2 = form([b contentView], @[@"Tabs:"], NSMakeRect(0, 3, 305, 45));
    [f setNextText:f2];
    button([b contentView], @"Set", NSMakeRect(232, 59, 72, 24), helvetica(12),
	styleToy, @selector(SetButton:));
    [styleToy setParameterForm:f];
    [styleToy setTabForm:f2];
    [styleToy setStylePanel:styleEditor];


//	Panel "Navigation"

    navigation = makePanel(@"Navigation", 76, 183, 206, 85);
    v = [navigation contentView];
    button(v, @"< Previous", NSMakeRect(6, 41, 71, 38), helvetica(12),
	hyperManager, @selector(previous:));
    button(v, @"Home", NSMakeRect(9, 10, 56, 22), helvetica(12),
	hyperManager, @selector(goHome:));
    button(v, @"Back up", NSMakeRect(82, 41, 57, 38), helvetica(12),
	hyperManager, @selector(back:));
    button(v, @"Next >", NSMakeRect(144, 41, 56, 38), helvetica(12),
	hyperManager, @selector(next:));
    button(v, @"Help", NSMakeRect(152, 8, 48, 24), helvetica(12),
	navHelp, @selector(makeKeyAndOrderFront:));


//	Panel "Other document" (an older version of the bottom of the
//	inspector; nothing in the menus shows it, but it is in the nib)

    otherDocument = makePanel(@"Other document", 579, 571, 473, 129);
    v = [otherDocument contentView];
    box(v, @"Diagnostics only", NSMakeRect(108, 8, 167, 57));
    f = form(v, @[@"Address :"], NSMakeRect(28, 65, 414, 32));
    bt = button(v, @"Open", NSMakeRect(366, 21, 96, 36), helveticaBold(16),
	hyperManager, @selector(open:));
    [f setTarget:bt];
    [f setAction:@selector(performClick:)];
    button(v, @"Open showing source", NSMakeRect(130, 20, 135, 24), helvetica(12),
	hyperManager, @selector(openSGML:));
    button(v, @"Link selection to", NSMakeRect(3, 102, 102, 25), helvetica(12),
	hyperManager, @selector(linkToString:));
    [otherDocument setDelegate:(id)hyperManager];


//	Panel "Document Inspector"

    inspector = makePanel(@"Document Inspector", 579, 362, 473, 339);
    v = [inspector contentView];
    f = form(v, @[@"Title:"], NSMakeRect(27, 280, 439, 45));
    bt = button(v, @"Set", NSMakeRect(383, 252, 82, 24), helvetica(12),
	hyperManager, @selector(setTitle:));
    [f setTarget:bt];
    [f setAction:@selector(performClick:)];
    [hyperManager setTitleString:f];
    t = label(v, @"", NSMakeRect(63, 202, 400, 36), helvetica(12));
    [t setSelectable:YES];
    [hyperManager setAddressString:t];
    label(v, @"Address:", NSMakeRect(5, 216, 58, 15), helvetica(12));
    f = form(v, @[@"Address :"], NSMakeRect(1, 71, 465, 32));
    [hyperManager setOpenString:f];
    label(v, @"Other document", NSMakeRect(55, 132, 144, 22), helvetica(18));
    button(v, @"Link selection to other document", NSMakeRect(270, 174, 192, 20), helvetica(12),
	hyperManager, @selector(linkToString:));
    label(v, @"______________________________________________",
	NSMakeRect(1, 161, 471, 22), helvetica(18));
    bt = button(v, @"Open", NSMakeRect(370, 30, 96, 36), helveticaBold(16),
	hyperManager, @selector(open:));
    [f setTarget:bt];
    [f setAction:@selector(performClick:)];
    button(v, @"Copy", NSMakeRect(6, 101, 41, 24), helvetica(12),
	hyperManager, @selector(copyAddress:));
    button(v, @"Inspect selected link", NSMakeRect(63, 174, 125, 20), helvetica(12),
	hyperManager, @selector(inspectLink:));
    box(v, @"Diagnostics only", NSMakeRect(60, 11, 167, 57));
    button(v, @"Open showing source", NSMakeRect(76, 23, 135, 24), helvetica(12),
	hyperManager, @selector(openSGML:));


//	Panel "Index Search"

    indexSearch = makePanel(@"Index Search", 579, 724, 473, 80);
    v = [indexSearch contentView];
    f = form(v, @[@"words:"], NSMakeRect(16, 43, 448, 30));
    bt = button(v, @"Search", NSMakeRect(357, 6, 107, 33), helveticaBold(14),
	hyperManager, @selector(search:));
    [f setTarget:bt];
    [f setAction:@selector(performClick:)];
    [hyperManager setKeywords:f];
    [textToy setSearchWindow:indexSearch];
    [indexSearch setDelegate:(id)hyperManager];


//	Access modules register with the manager when it is connected.

    [tcpAccess setManager:hyperManager];
    [fileAccess setManager:hyperManager];
    [newsAccess setManager:hyperManager];


//			The menus
//			=========
//
//	On NeXT the main menu was a vertical panel at the top left of the
//	screen, with submenus. Here TBL's main menu "WorldWideWeb" becomes the
//	menu bar: its first items (Info, and the application items Print,
//	Page layout, Services, Hide and Quit) go in the application menu, and
//	each of his submenus becomes a menu of the bar, in his order.
//	The titles and key equivalents are his.

    {
	NSMenu * bar = [[[NSMenu alloc] initWithTitle:@"WorldWideWeb"] autorelease];
	NSMenu * app, * m, * s;
	NSMenuItem * i;

	app = submenu(bar, @"WorldWideWeb");
	s = submenu(app, @"Info");
	item(s, @"Panel...", nil, info, @selector(makeKeyAndOrderFront:));
	item(s, @"Help...", nil, hyperManager, @selector(help:));
	[app addItem:[NSMenuItem separatorItem]];
	item(app, @"Print...", @"p", hyperManager, @selector(print:));
	item(app, @"Page layout...", nil, hyperManager, @selector(runPagelayout:));
	[app addItem:[NSMenuItem separatorItem]];
	s = submenu(app, @"Services");
	[NSApp setServicesMenu:s];
	[app addItem:[NSMenuItem separatorItem]];
	item(app, @"Hide", @"h", NSApp, @selector(hide:));
	item(app, @"Quit", @"q", NSApp, @selector(terminate:));

	m = submenu(bar, @"Navigate");
	item(m, @"Back", @"^", hyperManager, @selector(back:));
	item(m, @"Next", @">", hyperManager, @selector(next:));
	item(m, @"Previous", @"<", hyperManager, @selector(previous:));
	item(m, @"Home", @"H", hyperManager, @selector(goHome:));
	item(m, @"Panel...", nil, navigation, @selector(makeKeyAndOrderFront:));

	m = submenu(bar, @"Document");
	item(m, @"Open file...", @"o", fileAccess, @selector(open:));
	item(m, @"Open given document address", @"O", inspector, @selector(makeKeyAndOrderFront:));
	item(m, @"New file...", @"n", fileAccess, @selector(makeNew:));
	item(m, @"Save", @"s", hyperManager, @selector(save:));
	item(m, @"Save all edited windows", @"S", hyperManager, @selector(saveAll:));
	s = submenu(m, @"Save a copy in");
	item(s, @"HyperText Markup Language...", nil, fileAccess, @selector(saveAs:));
	item(s, @"Rich Text Format ...", nil, fileAccess, @selector(saveAsRichText:));
	item(s, @"Plain Text...", nil, fileAccess, @selector(saveAsPlainText:));
	item(s, @"PostScript...", nil, hyperManager, @selector(print:));
	item(m, @"Inspect ...", @"3", inspector, @selector(makeKeyAndOrderFront:));
	s = submenu(m, @"(Diagnostics)");
	item(s, @"Panel", nil, nil, NULL);		/* Not connected in the nib */
	item(s, @"Open HTML file showing SGML source", nil, fileAccess, @selector(openSGML:));
	item(s, @"Open HTML file showing RTF", nil, fileAccess, @selector(openRTF:));
	item(s, @"Dump text format to standard out", @"?", textToy, @selector(dump:));
	item(s, @"Turn console trace on", @"+", hyperManager, @selector(traceOn:));
	item(s, @"Turn console trace off", @"-", hyperManager, @selector(traceOff:));
	item(s, @"Item", nil, info, @selector(makeKeyAndOrderFront:));
	item(m, @"Miniaturize", nil, nil, @selector(performMiniaturize:));
	item(m, @"Open master template document", nil, hyperManager, @selector(goToBlank:));
	item(m, @"Close all other windows", @"W", hyperManager, @selector(closeOthers:));
	item(m, @"Close", @"w", nil, @selector(performClose:));

	m = submenu(bar, @"Edit");
	item(m, @"Cut", @"x", nil, @selector(cut:));
	item(m, @"Copy", @"c", nil, @selector(copy:));
	item(m, @"Paste", @"v", nil, @selector(paste:));
	submenu(m, @"Paste As");			/* Empty in the nib */
	item(m, @"Delete", nil, nil, @selector(delete:));
	item(m, @"Undo", @"z", nil, @selector(undo:));
	s = submenu(m, @"Find");
	i = item(s, @"Find Panel...", nil, nil, @selector(performFindPanelAction:));
	[i setTag:NSFindPanelActionShowFindPanel];
	i = item(s, @"Find Next", nil, nil, @selector(performFindPanelAction:));
	[i setTag:NSFindPanelActionNext];
	i = item(s, @"Find Previous", nil, nil, @selector(performFindPanelAction:));
	[i setTag:NSFindPanelActionPrevious];
	i = item(s, @"Enter Selection", nil, nil, @selector(performFindPanelAction:));
	[i setTag:NSFindPanelActionSetFindString];
	item(s, @"Jump To Selection", nil, nil, @selector(centerSelectionInVisibleArea:));
	item(m, @"Spelling...", nil, nil, @selector(showGuessPanel:));
	item(m, @"Check Spelling", @";", nil, @selector(checkSpelling:));
	item(m, @"Select All", @"a", nil, @selector(selectAll:));

//	Port: the nib gives Find's items no actions, so here they drive the
//	text view's find bar. Their key equivalents are only on this copy of
//	the menu (the Edit menu has another), and "Jump to Selection" has lost
//	its Command-j, which "Follow link" also uses and which worked on NeXT.

	m = submenu(bar, @"Find");
	i = item(m, @"Find Panel...", @"f", nil, @selector(performFindPanelAction:));
	[i setTag:NSFindPanelActionShowFindPanel];
	i = item(m, @"Find Next", @"g", nil, @selector(performFindPanelAction:));
	[i setTag:NSFindPanelActionNext];
	i = item(m, @"Find Previous", @"d", nil, @selector(performFindPanelAction:));
	[i setTag:NSFindPanelActionPrevious];
	i = item(m, @"Enter Selection", @"e", nil, @selector(performFindPanelAction:));
	[i setTag:NSFindPanelActionSetFindString];
	item(m, @"Jump to Selection", nil, nil, @selector(centerSelectionInVisibleArea:));

	m = submenu(bar, @"Links");
	item(m, @"Mark all ", @"A", textToy, @selector(markAll:));
	item(m, @"Mark selection ", @"M", textToy, @selector(markSelected:));
	item(m, @"Link to marked", @"L", textToy, @selector(linkToMark:));
	item(m, @"Link to file...", nil, fileAccess, @selector(linkToFile:));
	item(m, @"Link to New", @"N", fileAccess, @selector(linkToNew:));
	item(m, @"Follow link", @"j", textToy, @selector(followLink:));
	item(m, @"Unlink", @"Z", textToy, @selector(unlink:));
	item(m, @"Help", nil, linksHelp, @selector(makeKeyAndOrderFront:));

	m = submenu(bar, @"Style");
	item(m, @"Copy style", @"1", styleToy, @selector(PickButton:));
	item(m, @"Apply style", @"2", styleToy, @selector(ApplyButton:));
	item(m, @"Glossary", nil, styleToy, @selector(glossaryButton:));
	item(m, @"List", nil, styleToy, @selector(listButton:));
	item(m, @"Example", nil, styleToy, @selector(exampleButton:));
	item(m, @"Address", nil, styleToy, @selector(addressButton:));
	item(m, @"Normal", nil, styleToy, @selector(normalButton:));
	item(m, @"Heading 1", @"!", styleToy, @selector(heading1Button:));
	item(m, @"Heading 2", @"@", styleToy, @selector(heading2Button:));
	item(m, @"Heading 3", @"#", styleToy, @selector(heading3Button:));
	item(m, @"Heading 4", @"$", styleToy, @selector(heading4Button:));
	item(m, @"Panel...", nil, styleEditor, @selector(makeKeyAndOrderFront:));

	m = submenu(bar, @"Windows");
	item(m, @"Arrange in Front", nil, NSApp, @selector(arrangeInFront:));
	item(m, @"Miniaturize Window", @"m", nil, @selector(performMiniaturize:));
	item(m, @"Close Window", @"w", nil, @selector(performClose:));
	[NSApp setWindowsMenu:m];

	[NSApp setMainMenu:bar];

//	Port addition: TBL's main menu as a NeXT menu panel too, in his order
//	(see NeXTMenu.m). The NeXTMenu default turns it off.

	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NeXTMenu": @YES }];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NeXTMenu"]) {
	    NSMutableArray * main = [NSMutableArray array];
	    [main addObject:[app itemWithTitle:@"Info"]];
	    for (NSString * t in @[@"Navigate", @"Document", @"Edit", @"Find", @"Links", @"Style"])
		[main addObject:[bar itemWithTitle:t]];
	    [main addObject:[app itemWithTitle:@"Print..."]];
	    [main addObject:[app itemWithTitle:@"Page layout..."]];
	    [main addObject:[bar itemWithTitle:@"Windows"]];
	    for (NSString * t in @[@"Services", @"Hide", @"Quit"])
		[main addObject:[app itemWithTitle:t]];
	    NXMenuShowMain(@"WorldWideWeb", main);
	}
    }
}
