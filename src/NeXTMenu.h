/*	NeXTSTEP-style menus					NeXTMenu.h
**	====================
**
**	On NeXT, an application's menu was a narrow vertical panel at the top
**	left of the screen. Each submenu opened as another panel beside it,
**	and could be torn off and left anywhere. This draws such panels from
**	the application's NSMenuItems, so the actions, key equivalents and
**	enabling are the same as in the menu bar.
**
**	Port addition (2026), not part of the original. Turn it off with
**	    defaults write ch.cern.info.WorldWideWeb NeXTMenu NO
*/

#import <Cocoa/Cocoa.h>

/*	Show the main menu panel at the top left of the screen.
**	items are existing NSMenuItems, in the order the panel shows them.
**	While the panel is in use, the menu bar hides itself.
*/
extern void NXMenuShowMain(NSString * title, NSArray * items);
