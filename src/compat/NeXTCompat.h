/*	NeXTSTEP 3 compatibility layer for AppKit		NeXTCompat.h
**	=========================================
**
**	WorldWideWeb was written against the NeXTSTEP 3 Application Kit. This
**	file supplies the parts of that API which the original source uses,
**	built on modern Foundation and AppKit, so that TBL's files can stay as
**	close as possible to the way he wrote them.
**
**	The shim headers in this directory (appkit/appkit.h, objc/List.h,
**	streams/streams.h and so on) all import this one file.
**
**	Ported 2026. The original code is Copyright 1990-1995 CERN and MIT;
**	see NOTICE in the top directory.
*/

#ifndef NEXTCOMPAT_H
#define NEXTCOMPAT_H

#import <Cocoa/Cocoa.h>
#import <libc.h>

/*	Objects
**	-------
**	On NeXTSTEP the root class is Object, and -free releases an object.
**	This port uses manual reference counting (no ARC), so -free maps
**	straight onto -release.
*/
@compatibility_alias Object NSObject;

#define NXApp NSApp

@interface NSObject (NeXTObject)
- free;					/* Release and return nil */
- (BOOL)respondsTo:(SEL)aSelector;
@end


/*	List: the NeXT ordered collection
**	---------------------------------
**	objectAt: returns nil (not an exception) when the index is out of range,
**	and some of the original code depends on that.
*/
#define NX_NOT_IN_LIST 0xffffffff

@interface List : NSObject
{
    NSMutableArray * array;
}
- (unsigned)count;
- objectAt:(unsigned)index;
- lastObject;
- addObject:anObject;
- removeObject:anObject;
- removeLastObject;
- (unsigned)indexOf:anObject;
- makeObjectsPerform:(SEL)aSelector;
- copy;
@end


/*	Geometry and colours
**	--------------------
**	NXCoord is a float (not CGFloat), because the style sheet code reads
**	it with scanf("%f").
*/
typedef float NXCoord;
typedef NSRect NXRect;			/* (The SDK still has NXSize and NXPoint) */

#define NX_BLACK	0.0
#define NX_DKGRAY	(1.0/3.0)
#define NX_LTGRAY	(2.0/3.0)
#define NX_WHITE	1.0


/*	Streams
**	-------
**	An NXStream here is a byte buffer with a read position. A stream on a
**	file descriptor (NXOpenFile) fills the buffer from the descriptor as
**	the reader asks for more, so that a socket can be read as it arrives.
*/
#define NX_READONLY	1
#define NX_WRITEONLY	2
#define NX_READWRITE	3
#define NX_FREEBUFFER	0
#define NX_TRUNCATEBUFFER 1
#define NX_SAVEBUFFER	2

typedef struct _NXStream {
    unsigned char *	buf;
    size_t		len;		/* Bytes in buf */
    size_t		cap;		/* Bytes allocated */
    size_t		pos;		/* Read position */
    int			fd;		/* -1 unless NXOpenFile */
    int			eof;		/* fd has given end of file */
    int			mode;
} NXStream;

extern NXStream * NXMapFile(const char * path, int mode);
extern NXStream * NXOpenFile(int fd, int mode);
extern NXStream * NXOpenMemory(const char * addr, int size, int mode);
extern void	NXClose(NXStream * s);
extern void	NXCloseMemory(NXStream * s, int option);
extern int	NXSaveToFile(NXStream * s, const char * path);
extern void	NXFlush(NXStream * s);
extern long	NXTell(NXStream * s);
extern int	NXGetc(NXStream * s);
extern void	NXUngetc(NXStream * s);
extern BOOL	NXAtEOS(NXStream * s);
extern void	NXPrintf(NXStream * s, const char * format, ...)
				__attribute__((format(printf, 2, 3)));
extern int	NXScanf(NXStream * s, const char * format, ...);
extern void	NXWrite(NXStream * s, const void * bytes, size_t length);
extern NSData *	NXReadToEnd(NXStream * s);	/* Port: for Text readers */


/*	Character encoding
**	------------------
**	The NeXT used its own 8-bit character set. Documents in it, such as the
**	bundled ones, still read correctly; text which is valid UTF-8 is read as
**	UTF-8, which is what the web uses now.
*/
extern unichar	NXUnicharForByte(unsigned char c);	/* NeXTSTEP encoding */
extern NSString * NXStringFromBytes(const char * bytes, size_t length);
extern NSString * NXString(const char * cString);	/* nil-safe */
extern const char * NXCString(NSString * string);	/* UTF-8, autoreleased */


/*	Fonts
**	-----
**	NeXT font names are mapped onto the nearest Mac fonts. Ohlfs, the NeXT
**	fixed-width screen font, becomes Monaco. NXFontName() gives back the
**	NeXT name, so that saved style sheets keep the original names.
*/
@compatibility_alias Font NSFont;

@interface NSFont (NeXTFont)
+ newFont:(const char *)name size:(float)size;
@end
extern const char * NXFontName(NSFont * font);


/*	Defaults
**	--------
*/
typedef struct _NXDefault {
    const char * name;
    const char * value;
} NXDefaultsVector[];

extern int NXRegisterDefaults(const char * owner, const struct _NXDefault * vector);
extern const char * NXGetDefaultValue(const char * owner, const char * name);
extern int NXWriteDefault(const char * owner, const char * name, const char * value);


/*	Alert panels
**	------------
*/
#define NX_ALERTDEFAULT		1
#define NX_ALERTALTERNATE	0
#define NX_ALERTOTHER		(-1)
#define NX_ALERTERROR		(-2)

extern int NXRunAlertPanel(const char * title, const char * format,
	const char * defaultButton, const char * alternateButton,
	const char * otherButton, ...);


/*	Windows and the application
**	---------------------------
*/
@compatibility_alias Window NSWindow;
@compatibility_alias Panel NSPanel;
@compatibility_alias ScrollView NSScrollView;
@compatibility_alias Application NSApplication;

@interface NSWindow (NeXTWindow)
- setDocEdited:(BOOL)flag;
- (BOOL)isDocEdited;
@end
extern const char * NXWindowTitle(NSWindow * window);
extern void NXSetWindowTitle(NSWindow * window, const char * title);

@interface NSView (NeXTView)
- docView;				/* nil: only a ScrollView has one */
@end

@interface NSScrollView (NeXTScrollView)
- docView;
@end

@interface NSApplication (NeXTApplication)
- (List *)windowList;
- (NSPrintInfo *)printInfo;
@end

@compatibility_alias PrintInfo NSPrintInfo;

@interface NSPrintInfo (NeXTPrintInfo)
- (const NXRect *)paperRect;
- (const char *)paperType;
- setPaperType:(const char *)type andAdjust:(BOOL)flag;
- setVertCentered:(BOOL)flag;
- getMarginLeft:(NXCoord *)left right:(NXCoord *)right
	top:(NXCoord *)top bottom:(NXCoord *)bottom;
- setMarginLeft:(NXCoord)left right:(NXCoord)right
	top:(NXCoord)top bottom:(NXCoord)bottom;
@end


/*	Open and save panels
**	--------------------
**	These keep the NeXT calling conventions (C strings, a NULL-terminated
**	list of file types, and a status return).
*/
@interface OpenPanel : NSObject
{
    NSOpenPanel * panel;
    char * filename;
}
+ new;
- allowMultipleFiles:(BOOL)flag;
- (int)runModalForTypes:(const char * const *)types;
- (int)runModalForDirectory:(const char *)path file:(const char *)name
	types:(const char * const *)types;
- (const char *)filename;
@end

@interface SavePanel : NSObject
{
    NSSavePanel * panel;
    char * filename;
    char * requiredType;
}
+ new;
- setRequiredFileType:(const char *)type;
- (int)runModalForDirectory:(const char *)path file:(const char *)name;
- (const char *)filename;
@end


/*	Forms
**	-----
**	A Form is a column of titled text fields. NSForm is deprecated but still
**	works, so the port uses it with the NeXT accessors added.
*/
@interface Form : NSForm
- (const char *)stringValueAt:(int)index;
- setStringValue:(const char *)value at:(int)index;
- (float)floatValueAt:(int)index;
- setFloatValue:(float)value at:(int)index;
- selectTextAt:(int)index;
@end


/*	The Text object
**	===============
**
**	NeXT's Text kept its characters in a linked list of text blocks and its
**	formatting in an array of runs. HyperText works directly on those
**	structures, so the port keeps them: NXText (the base class of HyperText)
**	holds runs and blocks which mirror an NSTextStorage.
**
**	-	After the user edits the text, the runs and blocks are rebuilt
**		from the text storage.
**	-	When HyperText has changed runs or blocks itself, -calcLine copies
**		them back to the text storage. (On NeXT, calcLine recomputed the
**		line breaks from the same structures, so it was always called
**		after such changes.)
**
**	Text blocks hold unichars rather than NeXT bytes; see the comments at
**	OUTPUT in HyperText.m.
*/

#define NX_TEXTPER 1024			/* Characters per text block */

typedef struct _NXTabStop {
    short	kind;
    NXCoord	x;
} NXTabStop;

#define NX_LEFTTAB	0

typedef struct _NXTextStyle {
    NXCoord	indent1st;		/* Indent of first line of paragraph */
    NXCoord	indent2nd;		/* Indent of following lines */
    NXCoord	lineHt;			/* Line height */
    NXCoord	descentLine;		/* Descent of line */
    short	alignment;		/* NX_LEFTALIGNED etc */
    short	numTabs;
    NXTabStop *	tabs;
} NXTextStyle;

#define NX_LEFTALIGNED	0
#define NX_RIGHTALIGNED	1
#define NX_CENTERED	2
#define NX_JUSTIFIED	3

typedef struct _NXRun {
    id		font;			/* NSFont */
    int		chars;			/* Number of characters in run */
    void *	paraStyle;		/* NXTextStyle *, compared by pointer */
    float	textGray;
    int		textRGBColor;
    unsigned char superscript;
    unsigned char subscript;
    id		info;			/* HyperText keeps its Anchor here */
    struct _rFlags {
	unsigned int underline:1;
	unsigned int dummy:1;		/* HyperText: "this run has an anchor" */
	unsigned int subclassWantsRTF:1;
	unsigned int graphic:1;
	unsigned int forcedSymbol:1;
	unsigned int RESERVED:27;
    } rFlags;
} NXRun;

typedef struct _NXChunk {
    short	growby;			/* Bytes to grow by */
    int		allocated;		/* Bytes allocated */
    int		used;			/* Bytes used */
} NXChunk;

typedef struct _NXRunArray {
    NXChunk	chunk;
    NXRun	runs[1];
} NXRunArray;

extern NXChunk * NXChunkGrow(NXChunk * chunk, int newUsed);

typedef struct _NXTextBlock {
    struct _NXTextBlock * next;
    struct _NXTextBlock * prior;
    struct _tbFlags {
	unsigned int malloced:1;
	unsigned int PAD:15;
    } tbFlags;
    short	chars;			/* Characters used in block */
    unichar *	text;			/* Port: was unsigned char */
} NXTextBlock;

typedef struct _NXSelPt {
    int		cp;			/* Character position */
    int		line;
    NXCoord	x, y;
    int		c1st;
    NXCoord	ht;
} NXSelPt;

@interface NXText : NSTextView <NSTextViewDelegate, NSTextStorageDelegate>
{
@public
    NXRunArray *	theRuns;
    NXTextBlock *	firstTextBlock;
    NXTextBlock *	lastTextBlock;
    int			textLength;
    NXSelPt		sp0;		/* Start of selection */
    NXSelPt		spN;		/* End of selection */
    NXRun		typingRun;
    NXCoord		maxX, maxY;	/* Size of the text, set by calcLine */
    struct _tFlags {
	unsigned int monoFont:1;
	unsigned int changeState:1;	/* Delegate told about this change */
	unsigned int noWrap:1;
	unsigned int charWrap:1;
    } tFlags;
    id			delegate;	/* NeXT-style delegate (not NSTextView's) */
    BOOL		committing;	/* Port: we are writing the runs back */
}

- initFrame:(const NXRect *)frameRect;

- setDelegate:anObject;
- (int)textLength;

- setText:(const char *)aString;
- readText:(NXStream *)stream;
- readRichText:(NXStream *)stream;
- writeText:(NXStream *)stream;
- writeRichText:(NXStream *)stream;

- setSel:(int)start :(int)end;
- scrollSelToVisible;
- replaceSel:(const char *)aString length:(int)length runs:(NXRunArray *)insertRuns;
- selectText:sender;

- setMonoFont:(BOOL)flag;
- setNoWrap;
- setCharWrap:(BOOL)flag;
- setVertResizable:(BOOL)flag;
- setHorizResizable:(BOOL)flag;
- sizeTo:(NXCoord)width :(NXCoord)height;

- calcLine;			/* Port: copy runs and blocks to the storage */
- printPSCode:sender;

/*	Port: helpers for the parts of HyperText that need AppKit directly. */
- renewRunsFromStorage;
- takeTypingRun;
@end

@compatibility_alias Text NXText;

#endif /* NEXTCOMPAT_H */
