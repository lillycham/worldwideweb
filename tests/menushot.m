/*	Render NeXT menu panels to PNG files, without showing them.
**	Usage: menushot outdir
*/
#include "../src/NeXTMenu.m"

static void shoot(NXMenuPanel * p, NSString * path)
{
    NSView * v = [p contentView];
    NSBitmapImageRep * rep = [v bitmapImageRepForCachingDisplayInRect:[v bounds]];
    [v cacheDisplayInRect:[v bounds] toBitmapImageRep:rep];
    [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

int main(int argc, char ** argv)
{
    @autoreleasepool {
	NSString * dir = [NSString stringWithUTF8String:argv[1]];
	NSMenu * nav = [[NSMenu alloc] initWithTitle:@"Navigate"];
	NSMenu * bar = [[NSMenu alloc] initWithTitle:@"WorldWideWeb"];
	NSArray * names = @[@"Info", @"Navigate", @"Document", @"Edit", @"Find", @"Links",
	    @"Style", @"Print...", @"Page layout...", @"Windows", @"Services", @"Hide", @"Quit"];
	NSArray * keys = @[@"", @"", @"", @"", @"", @"", @"", @"p", @"", @"", @"", @"h", @"q"];
	NXMenuPanel * main, * sub;
	NSUInteger i;
	[NSApplication sharedApplication];
	[nav setAutoenablesItems:NO];
	[bar setAutoenablesItems:NO];
	[nav addItemWithTitle:@"Back" action:@selector(terminate:) keyEquivalent:@"^"];
	[nav addItemWithTitle:@"Next" action:@selector(terminate:) keyEquivalent:@">"];
	[nav addItemWithTitle:@"Previous" action:@selector(terminate:) keyEquivalent:@"<"];
	[nav addItemWithTitle:@"Home" action:@selector(terminate:) keyEquivalent:@"H"];
	[[nav addItemWithTitle:@"Panel..." action:@selector(terminate:) keyEquivalent:@""] setEnabled:NO];
	for (i = 0; i < [names count]; i++) {
	    NSMenuItem * it = [bar addItemWithTitle:names[i] action:@selector(terminate:) keyEquivalent:keys[i]];
	    if (i >= 1 && i <= 6) [it setSubmenu:[[NSMenu alloc] initWithTitle:names[i]]];
	    if (i == 9 || i == 10) [it setSubmenu:[[NSMenu alloc] initWithTitle:names[i]]];
	}
	[[bar itemWithTitle:@"Navigate"] setSubmenu:nav];
	main = [[NXMenuPanel alloc] initWithTitle:@"WorldWideWeb" items:[bar itemArray] parent:nil];
	main->openRow = 1;
	shoot(main, [dir stringByAppendingPathComponent:@"menu-main.png"]);
	sub = [main submenuPanelForRow:1];
	sub->tornOff = YES;
	sub->pressedRow = 1;
	shoot(sub, [dir stringByAppendingPathComponent:@"menu-navigate.png"]);
    }
    return 0;
}
