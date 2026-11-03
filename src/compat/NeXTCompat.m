/*	NeXTSTEP 3 compatibility layer for AppKit		NeXTCompat.m
**	=========================================
**
**	See NeXTCompat.h for what this is and why.
**
**	Ported 2026. The original code is Copyright 1990-1995 CERN and MIT;
**	see NOTICE in the top directory.
*/

#import "NeXTCompat.h"
#import <stdarg.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

extern int WWW_TraceFlag;


//			Objects
//			=======

@implementation NSObject (NeXTObject)

- free
{
    [self release];
    return nil;
}

- (BOOL)respondsTo:(SEL)aSelector
{
    return [self respondsToSelector:aSelector];
}

@end


@implementation List

- init
{
    if ((self = [super init])) array = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    [array release];
    [super dealloc];
}

- (unsigned)count			{ return (unsigned)[array count]; }

- objectAt:(unsigned)index
{
    return index < [array count] ? [array objectAtIndex:index] : nil;
}

- lastObject				{ return [array lastObject]; }

- addObject:anObject
{
    if (!anObject) return nil;
    [array addObject:anObject];
    return self;
}

//	NeXT List compared by identity, not with -isEqual:.
- removeObject:anObject
{
    NSUInteger i = [array indexOfObjectIdenticalTo:anObject];
    if (i == NSNotFound) return nil;
    [[anObject retain] autorelease];
    [array removeObjectAtIndex:i];
    return anObject;
}

- removeLastObject
{
    id last = [[[array lastObject] retain] autorelease];
    if (last) [array removeLastObject];
    return last;
}

- (unsigned)indexOf:anObject
{
    NSUInteger i = [array indexOfObjectIdenticalTo:anObject];
    return i == NSNotFound ? NX_NOT_IN_LIST : (unsigned)i;
}

- makeObjectsPerform:(SEL)aSelector
{
    [[[array copy] autorelease] makeObjectsPerformSelector:aSelector];
    return self;
}

- copy
{
    List * other = [[List alloc] init];
    [other->array addObjectsFromArray:array];
    return other;
}

@end


//			Streams
//			=======

static NXStream * stream_new(int mode)
{
    NXStream * s = calloc(1, sizeof(*s));
    s->fd = -1;
    s->mode = mode;
    return s;
}

static void stream_reserve(NXStream * s, size_t extra)
{
    if (s->len + extra + 1 > s->cap) {
	size_t cap = s->cap ? s->cap : 4096;
	while (cap < s->len + extra + 1) cap *= 2;
	s->buf = realloc(s->buf, cap);
	s->cap = cap;
    }
}

void NXWrite(NXStream * s, const void * bytes, size_t length)
{
    stream_reserve(s, length);
    memcpy(s->buf + s->len, bytes, length);
    s->len += length;
    s->buf[s->len] = 0;			/* Keep it a C string for NXScanf */
}

//	Read more from the file descriptor, if there is one.
//	Returns NO at end of file.
static BOOL stream_fill(NXStream * s)
{
    unsigned char chunk[8192];
    ssize_t n;
    if (s->fd < 0 || s->eof) return NO;
    do {
	n = read(s->fd, chunk, sizeof(chunk));
    } while (n < 0 && errno == EINTR);
    if (n <= 0) {
	s->eof = 1;
	return NO;
    }
    NXWrite(s, chunk, (size_t)n);
    return YES;
}

NXStream * NXMapFile(const char * path, int mode)
{
    NXStream * s;
    int fd;
    if (mode == NX_WRITEONLY) return stream_new(mode);
    fd = open(path, O_RDONLY);
    if (fd < 0) return NULL;
    s = stream_new(mode);
    s->fd = fd;
    while (stream_fill(s)) ;
    close(fd);
    s->fd = -1;
    return s;
}

NXStream * NXOpenFile(int fd, int mode)
{
    NXStream * s = stream_new(mode);
    if (mode != NX_WRITEONLY) s->fd = fd;
    return s;
}

NXStream * NXOpenMemory(const char * addr, int size, int mode)
{
    NXStream * s = stream_new(mode);
    if (addr && size > 0) NXWrite(s, addr, (size_t)size);
    return s;
}

void NXClose(NXStream * s)
{
    if (!s) return;
    free(s->buf);
    free(s);
}

void NXCloseMemory(NXStream * s, int option)
{
    NXClose(s);
}

int NXSaveToFile(NXStream * s, const char * path)
{
    FILE * fp = fopen(path, "w");
    if (!fp) return -1;
    if (s->len) fwrite(s->buf, 1, s->len, fp);
    fclose(fp);
    return 0;
}

void NXFlush(NXStream * s)		{ }
long NXTell(NXStream * s)		{ return (long)(s->mode == NX_WRITEONLY ? s->len : s->pos); }

int NXGetc(NXStream * s)
{
    if (s->pos >= s->len && !stream_fill(s)) {
	s->pos++;			/* So that NXUngetc after EOF works */
	return -1;
    }
    return s->buf[s->pos++];
}

void NXUngetc(NXStream * s)
{
    if (s->pos > 0) s->pos--;
}

BOOL NXAtEOS(NXStream * s)
{
    if (s->pos < s->len) return NO;
    return !stream_fill(s);
}

void NXPrintf(NXStream * s, const char * format, ...)
{
    va_list ap;
    char * text = NULL;
    int n;
    va_start(ap, format);
    n = vasprintf(&text, format, ap);
    va_end(ap);
    if (n > 0) NXWrite(s, text, (size_t)n);
    free(text);
}

//	Scan from the stream like scanf(). We give vfscanf a FILE on the rest of
//	the buffer, and see how far it got.
int NXScanf(NXStream * s, const char * format, ...)
{
    va_list ap;
    FILE * fp;
    int n;
    while (stream_fill(s)) ;
    if (s->pos >= s->len) return EOF;
    fp = fmemopen(s->buf + s->pos, s->len - s->pos, "r");
    if (!fp) return EOF;
    va_start(ap, format);
    n = vfscanf(fp, format, ap);
    va_end(ap);
    s->pos += (size_t)ftell(fp);
    fclose(fp);
    return n;
}

NSData * NXReadToEnd(NXStream * s)
{
    NSData * data;
    while (stream_fill(s)) ;
    if (s->pos >= s->len) return [NSData data];
    data = [NSData dataWithBytes:s->buf + s->pos length:s->len - s->pos];
    s->pos = s->len;
    return data;
}


//			Character encoding
//			==================

unichar NXUnicharForByte(unsigned char c)
{
    static unichar table[256];
    static BOOL ready = NO;
    if (c < 128) return c;
    if (!ready) {
	int i;
	for (i = 0; i < 256; i++) {
	    unsigned char b = (unsigned char)i;
	    NSString * s = [[NSString alloc] initWithBytes:&b length:1
				encoding:NSNEXTSTEPStringEncoding];
	    table[i] = [s length] ? [s characterAtIndex:0] : 0xFFFD;
	    [s release];
	}
	ready = YES;
    }
    return table[c];
}

NSString * NXStringFromBytes(const char * bytes, size_t length)
{
    NSString * s;
    if (!bytes) return @"";
    s = [[NSString alloc] initWithBytes:bytes length:length
		encoding:NSUTF8StringEncoding];
    if (!s) s = [[NSString alloc] initWithBytes:bytes length:length
		encoding:NSNEXTSTEPStringEncoding];
    return [s autorelease];
}

NSString * NXString(const char * cString)
{
    return cString ? NXStringFromBytes(cString, strlen(cString)) : @"";
}

const char * NXCString(NSString * string)
{
    return string ? [string UTF8String] : "";
}


//			Fonts
//			=====

static const char * fontMap[][2] = {		/* NeXT name, Mac name */
    { "Ohlfs",			"Monaco" },
    { "Courier",		"Courier" },
    { "Helvetica-BoldOblique",	"Helvetica-BoldOblique" },
    { NULL, NULL }
};

@implementation NSFont (NeXTFont)

//	Like NeXT's, this returns nil if there is no such font. The style sheet
//	asks for "Helvetica-Bold-Oblique", which is not a real font name, so
//	Heading5 gets the default font, as it did on the NeXT.
+ newFont:(const char *)name size:(float)size
{
    int i;
    const char * macName = name;
    if (!name) return nil;
    for (i = 0; fontMap[i][0]; i++)
	if (strcmp(name, fontMap[i][0]) == 0) macName = fontMap[i][1];
    return [NSFont fontWithName:NXString(macName) size:size];
}

@end

const char * NXFontName(NSFont * font)
{
    int i;
    const char * name;
    if (!font) return "(None)";
    name = [[font fontName] UTF8String];
    for (i = 0; fontMap[i][0]; i++)
	if (strcmp(name, fontMap[i][1]) == 0) return fontMap[i][0];
    return name;
}


//			Defaults
//			========
//
//	Defaults owned by WorldWideWeb are stored under their own names.
//	Others (such as "News" "NewsHost") are stored as "Owner.Name".

static NSString * defaultKey(const char * owner, const char * name)
{
    if (owner && strcmp(owner, "WorldWideWeb") != 0)
	return [NSString stringWithFormat:@"%s.%s", owner, name];
    return NXString(name);
}

int NXRegisterDefaults(const char * owner, const struct _NXDefault * vector)
{
    NSMutableDictionary * d = [NSMutableDictionary dictionary];
    for (; vector->name; vector++)
	[d setObject:NXString(vector->value) forKey:defaultKey(owner, vector->name)];
    [[NSUserDefaults standardUserDefaults] registerDefaults:d];
    return 1;
}

const char * NXGetDefaultValue(const char * owner, const char * name)
{
    static NSMutableDictionary * cache;	/* Keeps the C strings alive */
    NSString * key = defaultKey(owner, name);
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (!value) return NULL;
    if (![value isKindOfClass:[NSString class]]) value = [value description];
    if (!cache) cache = [[NSMutableDictionary alloc] init];
    [cache setObject:value forKey:key];
    return [value UTF8String];
}

int NXWriteDefault(const char * owner, const char * name, const char * value)
{
    [[NSUserDefaults standardUserDefaults] setObject:NXString(value)
	forKey:defaultKey(owner, name)];
    return 1;
}


//			Alert panels
//			============

int NXRunAlertPanel(const char * title, const char * format,
	const char * defaultButton, const char * alternateButton,
	const char * otherButton, ...)
{
    va_list ap;
    char * message = NULL;
    NSAlert * alert = [[[NSAlert alloc] init] autorelease];
    NSModalResponse response;

    va_start(ap, otherButton);
    vasprintf(&message, format ? format : "", ap);
    va_end(ap);

    [alert setMessageText:NXString(title ? title : "Alert")];
    [alert setInformativeText:NXString(message)];
    free(message);
    [alert addButtonWithTitle:NXString(defaultButton ? defaultButton : "OK")];
    if (alternateButton) [alert addButtonWithTitle:NXString(alternateButton)];
    if (otherButton) [alert addButtonWithTitle:NXString(otherButton)];

    response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) return NX_ALERTDEFAULT;
    if (response == NSAlertSecondButtonReturn)
	return alternateButton ? NX_ALERTALTERNATE : NX_ALERTOTHER;
    return NX_ALERTOTHER;
}


//			Windows and the application
//			===========================

@implementation NSWindow (NeXTWindow)

- setDocEdited:(BOOL)flag
{
    [self setDocumentEdited:flag];
    return self;
}

- (BOOL)isDocEdited		{ return [self isDocumentEdited]; }

@end

const char * NXWindowTitle(NSWindow * window)
{
    return window ? [[window title] UTF8String] : "";
}

void NXSetWindowTitle(NSWindow * window, const char * title)
{
    [window setTitle:NXString(title)];
}

@implementation NSView (NeXTView)
- docView			{ return nil; }
@end

@implementation NSScrollView (NeXTScrollView)
- docView			{ return [self documentView]; }
@end

@implementation NSApplication (NeXTApplication)

- (List *)windowList
{
    List * list = [[[List alloc] init] autorelease];
    for (NSWindow * w in [self windows]) [list addObject:w];
    return list;
}

- (NSPrintInfo *)printInfo	{ return [NSPrintInfo sharedPrintInfo]; }

@end


static const char * paperNames[][2] = {		/* NeXT name, Cocoa name */
    { "Letter",	"na-letter" },
    { "Legal",	"na-legal" },
    { "A4",	"iso-a4" },
    { "A5",	"iso-a5" },
    { "B5",	"iso-b5" },
    { NULL, NULL }
};

@implementation NSPrintInfo (NeXTPrintInfo)

- (const NXRect *)paperRect
{
    static NXRect rect;
    rect.origin = NSZeroPoint;
    rect.size = [self paperSize];
    return &rect;
}

- (const char *)paperType
{
    int i;
    const char * name = [[self paperName] UTF8String];
    if (!name) return "";
    for (i = 0; paperNames[i][0]; i++)
	if (strcmp(name, paperNames[i][1]) == 0) return paperNames[i][0];
    return name;
}

- setPaperType:(const char *)type andAdjust:(BOOL)flag
{
    int i;
    if (!type) return nil;
    for (i = 0; paperNames[i][0]; i++)
	if (strcasecmp(type, paperNames[i][0]) == 0) type = paperNames[i][1];
    [self setPaperName:NXString(type)];
    return self;
}

- setVertCentered:(BOOL)flag
{
    [self setVerticallyCentered:flag];
    return self;
}

- getMarginLeft:(NXCoord *)left right:(NXCoord *)right
	top:(NXCoord *)top bottom:(NXCoord *)bottom
{
    *left = [self leftMargin];
    *right = [self rightMargin];
    *top = [self topMargin];
    *bottom = [self bottomMargin];
    return self;
}

- setMarginLeft:(NXCoord)left right:(NXCoord)right
	top:(NXCoord)top bottom:(NXCoord)bottom
{
    [self setLeftMargin:left];
    [self setRightMargin:right];
    [self setTopMargin:top];
    [self setBottomMargin:bottom];
    return self;
}

@end


//			Open and save panels
//			====================

static NSArray * contentTypes(const char * const * types)
{
    NSMutableArray * a = [NSMutableArray array];
    if (!types) return nil;
    for (; *types; types++) {
	UTType * t = [UTType typeWithFilenameExtension:NXString(*types)];
	if (t) [a addObject:t];
    }
    return [a count] ? a : nil;
}

@implementation OpenPanel

+ new
{
    OpenPanel * me = [[self alloc] init];
    me->panel = [[NSOpenPanel openPanel] retain];
    [me->panel setCanChooseDirectories:NO];
    return me;
}

- allowMultipleFiles:(BOOL)flag
{
    [panel setAllowsMultipleSelection:flag];
    return self;
}

- (int)runModalForDirectory:(const char *)path file:(const char *)name
	types:(const char * const *)types
{
    NSArray * t = contentTypes(types);
    [panel setAllowedContentTypes:t ? t : @[]];
    if (path) [panel setDirectoryURL:[NSURL fileURLWithPath:NXString(path)]];
    if ([panel runModal] != NSModalResponseOK) return 0;
    free(filename);
    filename = strdup([[[panel URL] path] UTF8String]);
    return 1;
}

- (int)runModalForTypes:(const char * const *)types
{
    return [self runModalForDirectory:NULL file:NULL types:types];
}

- (const char *)filename	{ return filename; }

@end

@implementation SavePanel

+ new
{
    SavePanel * me = [[self alloc] init];
    me->panel = [[NSSavePanel savePanel] retain];
    return me;
}

- setRequiredFileType:(const char *)type
{
    UTType * t = (type && *type) ? [UTType typeWithFilenameExtension:NXString(type)] : nil;
    [panel setAllowedContentTypes:t ? @[t] : @[]];
    return self;
}

- (int)runModalForDirectory:(const char *)path file:(const char *)name
{
    if (path && *path) [panel setDirectoryURL:[NSURL fileURLWithPath:NXString(path)]];
    if (name) [panel setNameFieldStringValue:NXString(name)];
    if ([panel runModal] != NSModalResponseOK) return 0;
    free(filename);
    filename = strdup([[[panel URL] path] UTF8String]);
    return 1;
}

- (const char *)filename	{ return filename; }

@end


//			Forms
//			=====

@implementation Form

- (const char *)stringValueAt:(int)index
{
    return NXCString([[self cellAtIndex:index] stringValue]);
}

- setStringValue:(const char *)value at:(int)index
{
    [[self cellAtIndex:index] setStringValue:NXString(value)];
    return self;
}

- (float)floatValueAt:(int)index
{
    return [[self cellAtIndex:index] floatValue];
}

- setFloatValue:(float)value at:(int)index
{
    [[self cellAtIndex:index] setFloatValue:value];
    return self;
}

- selectTextAt:(int)index
{
    [self selectTextAtIndex:index];
    return self;
}

@end


//			The Text object
//			===============

NXChunk * NXChunkGrow(NXChunk * chunk, int newUsed)
{
    NXRunArray * a = (NXRunArray *)chunk;
    int want = newUsed;
    if (a->chunk.growby > 0) want = newUsed + a->chunk.growby;
    a = realloc(a, offsetof(NXRunArray, runs) + want + sizeof(NXRun)); /* + sentinel */
    a->chunk.allocated = want;
    return &a->chunk;
}

//	Attribute names for the run fields which have no AppKit equivalent.
//	These live in the text storage alongside the real font and paragraph
//	style, so that the runs can be rebuilt from it.

static NSString * const NXParaStyleAttribute	= @"NXRunParaStyle";
static NSString * const NXInfoAttribute		= @"NXRunInfo";
static NSString * const NXGrayAttribute		= @"NXRunTextGray";
static NSString * const NXRGBAttribute		= @"NXRunTextRGBColor";
static NSString * const NXFlagsAttribute	= @"NXRunFlags";
static NSString * const NXScriptAttribute	= @"NXRunScript";

static NSFont * defaultFont(void)
{
    return [NSFont fontWithName:@"Helvetica" size:12.0];
}

static unsigned int flagsOf(NXRun * r)
{
    unsigned int f;
    memcpy(&f, &r->rFlags, sizeof(f));
    return f;
}

//	Make an NSParagraphStyle which looks like a NeXT one.
//	Note that NXTextStyle has no space before or after: TBL simulated those
//	with blank lines (see output_paragraph() in ParseHTML.h).
static NSParagraphStyle * paragraphFor(NXTextStyle * p)
{
    NSMutableParagraphStyle * ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    int i;
    NSMutableArray * tabs = [NSMutableArray array];
    if (!p) return ps;
    [ps setFirstLineHeadIndent:p->indent1st];
    [ps setHeadIndent:p->indent2nd];
    if (p->lineHt > 0) {
	[ps setMinimumLineHeight:p->lineHt];
	[ps setMaximumLineHeight:p->lineHt];
    }
    switch (p->alignment) {
    case NX_RIGHTALIGNED:	[ps setAlignment:NSTextAlignmentRight]; break;
    case NX_CENTERED:		[ps setAlignment:NSTextAlignmentCenter]; break;
    case NX_JUSTIFIED:		[ps setAlignment:NSTextAlignmentJustified]; break;
    default:			[ps setAlignment:NSTextAlignmentLeft]; break;
    }
    for (i = 0; i < p->numTabs; i++)
	[tabs addObject:[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft
	    location:p->tabs[i].x options:@{}] autorelease]];
    [ps setTabStops:tabs];
    return ps;
}

static NSDictionary * attributesFor(NXRun * r, NSMutableDictionary * paraCache)
{
    NSMutableDictionary * a = [NSMutableDictionary dictionary];
    float gray = r->textGray;
    [a setObject:(r->font ? r->font : defaultFont()) forKey:NSFontAttributeName];
    if (r->paraStyle) {
	NSValue * key = [NSValue valueWithPointer:r->paraStyle];
	NSParagraphStyle * ps = [paraCache objectForKey:key];
	if (!ps) {
	    ps = paragraphFor((NXTextStyle *)r->paraStyle);
	    [paraCache setObject:ps forKey:key];
	}
	[a setObject:ps forKey:NSParagraphStyleAttributeName];
	[a setObject:key forKey:NXParaStyleAttribute];
    }
    if (gray < 0 || gray > 1) gray = 0;
    [a setObject:[NSColor colorWithCalibratedWhite:gray alpha:1.0]
	forKey:NSForegroundColorAttributeName];
    [a setObject:@(r->textGray) forKey:NXGrayAttribute];
    [a setObject:@(r->textRGBColor) forKey:NXRGBAttribute];
    if (r->info) [a setObject:r->info forKey:NXInfoAttribute];
    if (r->rFlags.underline)
	[a setObject:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
    [a setObject:@(flagsOf(r)) forKey:NXFlagsAttribute];
    if (r->superscript || r->subscript) {
	[a setObject:@((r->superscript << 8) | r->subscript) forKey:NXScriptAttribute];
	[a setObject:@((float)r->superscript - (float)r->subscript)
	    forKey:NSBaselineOffsetAttributeName];
    }
    return a;
}

static void runFromAttributes(NXRun * r, NSDictionary * a)
{
    NSNumber * n;
    unsigned int f;
    memset(r, 0, sizeof(*r));
    r->font = [a objectForKey:NSFontAttributeName];
    r->paraStyle = [[a objectForKey:NXParaStyleAttribute] pointerValue];
    n = [a objectForKey:NXGrayAttribute];
    r->textGray = n ? [n floatValue] : NX_BLACK;
    n = [a objectForKey:NXRGBAttribute];
    r->textRGBColor = n ? [n intValue] : -1;
    r->info = [a objectForKey:NXInfoAttribute];
    n = [a objectForKey:NXFlagsAttribute];
    f = n ? [n unsignedIntValue] : 0;
    memcpy(&r->rFlags, &f, sizeof(f));
    if ([a objectForKey:NSUnderlineStyleAttributeName]) r->rFlags.underline = 1;
    n = [a objectForKey:NXScriptAttribute];
    if (n) {
	r->superscript = ([n intValue] >> 8) & 0xff;
	r->subscript = [n intValue] & 0xff;
    }
}

static BOOL sameFormat(NXRun * r1, NXRun * r2)
{
    return r1->font == r2->font && r1->paraStyle == r2->paraStyle
	&& r1->textGray == r2->textGray && r1->textRGBColor == r2->textRGBColor
	&& r1->superscript == r2->superscript && r1->subscript == r2->subscript
	&& r1->info == r2->info && flagsOf(r1) == flagsOf(r2);
}


@implementation NXText

- initFrame:(const NXRect *)frameRect
{
    if (!(self = [super initWithFrame:*frameRect])) return nil;
    [super setDelegate:self];
    [[self textStorage] setDelegate:self];
    [self setRichText:YES];
    [self setImportsGraphics:NO];
    [self setUsesFontPanel:YES];
    [self setUsesFindPanel:YES];
    [self setAllowsUndo:YES];
    [self setAutomaticQuoteSubstitutionEnabled:NO];
    [self setAutomaticDashSubstitutionEnabled:NO];
    [self setAutomaticTextReplacementEnabled:NO];
    [self setAutomaticSpellingCorrectionEnabled:NO];
    [self setAutomaticLinkDetectionEnabled:NO];
    [self setSmartInsertDeleteEnabled:NO];
    [self setTextContainerInset:NSMakeSize(0, 0)];
    [[self textContainer] setLineFragmentPadding:2.0];
    [self setFont:defaultFont()];
    typingRun.font = defaultFont();
    typingRun.textGray = NX_BLACK;
    typingRun.textRGBColor = -1;
    [self renewRunsFromStorage];
    return self;
}

- (void)dealloc
{
    NXTextBlock * b, * next;
    [[self textStorage] setDelegate:nil];
    for (b = firstTextBlock; b; b = next) {
	next = b->next;
	free(b->text);
	free(b);
    }
    free(theRuns);
    [super dealloc];
}

//	The window owns this view and releases it when it closes, so -free
//	must not release it again. (HyperText's -free does its own clean up
//	and then calls this.)
- free				{ return nil; }

- setDelegate:anObject
{
    delegate = anObject;		/* Not [super setDelegate:] - see .h */
    return self;
}

- (int)textLength		{ return textLength; }


//	Rebuild the runs and text blocks from the text storage
//	------------------------------------------------------

- renewRunsFromStorage
{
    NSTextStorage * ts = [self textStorage];
    NSString * string = [ts string];
    NSUInteger length = [string length];
    NXTextBlock * b, * next, * prior = NULL;
    NSUInteger pos;
    __block int n = 0;
    __block int cap = 16;
    __block NXRunArray * runs;

//	Text blocks: each holds up to NX_TEXTPER characters. Each has room for
//	NX_TEXTPER more, because the HTML parser appends to the last block
//	in place (see append_begin() in HyperText.m).

    for (b = firstTextBlock; b; b = next) {
	next = b->next;
	free(b->text);
	free(b);
    }
    firstTextBlock = lastTextBlock = NULL;
    pos = 0;
    do {
	NSUInteger chars = MIN((NSUInteger)NX_TEXTPER, length - pos);
	b = calloc(1, sizeof(*b));
	b->text = malloc((chars + NX_TEXTPER) * sizeof(unichar));
	[string getCharacters:b->text range:NSMakeRange(pos, chars)];
	b->chars = (short)chars;
	b->tbFlags.malloced = 1;
	b->prior = prior;
	if (prior) prior->next = b; else firstTextBlock = b;
	prior = b;
	pos += chars;
    } while (pos < length);
    lastTextBlock = prior;
    textLength = (int)length;

//	Runs: one for each stretch of identical formatting.

    runs = malloc(offsetof(NXRunArray, runs) + (cap + 1) * sizeof(NXRun));
    if (length) {
	[ts enumerateAttributesInRange:NSMakeRange(0, length) options:0
	    usingBlock:^(NSDictionary * attrs, NSRange range, BOOL * stop) {
		NXRun r;
		runFromAttributes(&r, attrs);
		r.chars = (int)range.length;
		if (n > 0 && sameFormat(&runs->runs[n-1], &r)) {
		    runs->runs[n-1].chars += r.chars;
		    return;
		}
		if (n == cap) {
		    cap *= 2;
		    runs = realloc(runs, offsetof(NXRunArray, runs) + (cap + 1) * sizeof(NXRun));
		}
		runs->runs[n++] = r;
	    }];
    } else {
	runs->runs[0] = typingRun;	/* NeXT Text always had one run */
	runs->runs[0].chars = 0;
	n = 1;
    }

//	A sentinel run after the end stops loops which scan for a position
//	at the very end of the text from running off the array.

    runs->runs[n] = runs->runs[n-1];
    runs->runs[n].chars = INT_MAX / 2;
    runs->chunk.growby = 16 * sizeof(NXRun);
    runs->chunk.allocated = cap * (int)sizeof(NXRun);
    runs->chunk.used = n * (int)sizeof(NXRun);
    free(theRuns);
    theRuns = runs;

    [self syncSelection];
    return self;
}

//	Copy the runs and blocks back into the text storage
//	---------------------------------------------------

- calcLine
{
    NSMutableString * string = [NSMutableString string];
    NSMutableAttributedString * text;
    NSMutableDictionary * paraCache = [NSMutableDictionary dictionary];
    NXTextBlock * b;
    int i, pos = 0;
    int n = theRuns->chunk.used / (int)sizeof(NXRun);
    NSRange sel = [self selectedRange];

    for (b = firstTextBlock; b; b = b->next)
	if (b->chars > 0)
	    [string appendString:[NSString stringWithCharacters:b->text length:b->chars]];
    text = [[[NSMutableAttributedString alloc] initWithString:string] autorelease];
    for (i = 0; i < n && pos < (int)[string length]; i++) {
	NXRun * r = &theRuns->runs[i];
	int chars = r->chars;
	if (chars <= 0) continue;
	if (i == n-1 || pos + chars > (int)[string length])
	    chars = (int)[string length] - pos;	/* Last run takes the rest */
	[text setAttributes:attributesFor(r, paraCache) range:NSMakeRange(pos, chars)];
	pos += chars;
    }
    if (pos < (int)[string length] && n > 0)
	[text setAttributes:attributesFor(&theRuns->runs[n-1], paraCache)
	    range:NSMakeRange(pos, [string length] - pos)];

    committing = YES;
    [[self textStorage] setAttributedString:text];
    committing = NO;
    [self renewRunsFromStorage];

    if (NSMaxRange(sel) <= [string length]) [self setSelectedRange:sel];
    [self measure];
    return self;
}

//	Find the size of the laid-out text, as NeXT Text kept in maxX and maxY.
- measure
{
    NSLayoutManager * lm = [self layoutManager];
    NSRect used;
    [lm ensureLayoutForTextContainer:[self textContainer]];
    used = [lm usedRectForTextContainer:[self textContainer]];
    maxX = ceil(NSMaxX(used) + 2 * [[self textContainer] lineFragmentPadding]);
    maxY = ceil(NSMaxY(used));
    return self;
}

//	After the user (or AppKit) has changed the text, pick up the changes.
- (void)textStorage:(NSTextStorage *)textStorage
	didProcessEditing:(NSTextStorageEditActions)editedMask
	range:(NSRange)editedRange changeInLength:(NSInteger)delta
{
    if (!committing) [self renewRunsFromStorage];
}


//	Selection
//	---------

- syncSelection
{
    NSRange r = [self selectedRange];
    if (r.location == NSNotFound) r = NSMakeRange(0, 0);
    if ((int)NSMaxRange(r) > textLength) r = NSMakeRange(textLength, 0);
    sp0.cp = (int)r.location;
    spN.cp = (int)NSMaxRange(r);
    return self;
}

- (void)setSelectedRanges:(NSArray *)ranges affinity:(NSSelectionAffinity)affinity
	stillSelecting:(BOOL)stillSelecting
{
    [super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelecting];
    [self syncSelection];
}

- setSel:(int)start :(int)end
{
    if (start < 0) start = 0;
    if (end > textLength) end = textLength;
    if (end < start) end = start;
    [self setSelectedRange:NSMakeRange(start, end - start)];
    return self;
}

- scrollSelToVisible
{
    [self scrollRangeToVisible:[self selectedRange]];
    return self;
}

- selectText:sender
{
    [self selectAll:sender];
    return self;
}

//	Typing run
//	----------
//
//	When a style is applied with nothing selected, HyperText changes the
//	typing run. Here that becomes the text view's typing attributes.

- takeTypingRun
{
    NSMutableDictionary * cache = [NSMutableDictionary dictionary];
    [self setTypingAttributes:attributesFor(&typingRun, cache)];
    return self;
}

- (void)setTypingAttributes:(NSDictionary *)attrs
{
    [super setTypingAttributes:attrs];
    runFromAttributes(&typingRun, attrs);
}


//	Replacing text
//	--------------

- setText:(const char *)aString
{
    NSMutableDictionary * cache = [NSMutableDictionary dictionary];
    NSString * s = NXString(aString);
    committing = YES;
    [[self textStorage] setAttributedString:[[[NSAttributedString alloc]
	initWithString:s attributes:attributesFor(&typingRun, cache)] autorelease]];
    committing = NO;
    [self setSelectedRange:NSMakeRange(0, 0)];
    [self renewRunsFromStorage];
    [self measure];
    return self;
}

- replaceSel:(const char *)aString length:(int)length runs:(NXRunArray *)insertRuns
{
    NSString * s = NXStringFromBytes(aString, (size_t)length);
    NSMutableAttributedString * text = [[[NSMutableAttributedString alloc]
	initWithString:s] autorelease];
    NSMutableDictionary * cache = [NSMutableDictionary dictionary];
    NSRange sel = [self selectedRange];
    int i, pos = 0;
    int n = insertRuns->chunk.used / (int)sizeof(NXRun);
    for (i = 0; i < n && pos < (int)[s length]; i++) {
	int chars = MIN(insertRuns->runs[i].chars, (int)[s length] - pos);
	if (i == n-1) chars = (int)[s length] - pos;
	[text setAttributes:attributesFor(&insertRuns->runs[i], cache)
	    range:NSMakeRange(pos, chars)];
	pos += chars;
    }
    committing = YES;
    [[self textStorage] replaceCharactersInRange:sel withAttributedString:text];
    committing = NO;
    [self setSelectedRange:NSMakeRange(sel.location + [s length], 0)];
    [self renewRunsFromStorage];
    [self measure];
    return self;
}

- readText:(NXStream *)stream
{
    NSData * data = NXReadToEnd(stream);
    NSString * s = NXStringFromBytes([data bytes], [data length]);
    NSMutableDictionary * cache = [NSMutableDictionary dictionary];
    NXRun r = typingRun;
    r.font = [self font] ? [self font] : defaultFont();
    r.paraStyle = 0;
    r.info = nil;
    committing = YES;
    [[self textStorage] setAttributedString:[[[NSAttributedString alloc]
	initWithString:s attributes:attributesFor(&r, cache)] autorelease]];
    committing = NO;
    [self setSelectedRange:NSMakeRange(0, 0)];
    [self renewRunsFromStorage];
    [self measure];
    return self;
}

- readRichText:(NXStream *)stream
{
    NSData * data = NXReadToEnd(stream);
    NSAttributedString * text = [[[NSAttributedString alloc] initWithRTF:data
	documentAttributes:NULL] autorelease];
    if (!text) return nil;
    committing = YES;
    [[self textStorage] setAttributedString:text];
    committing = NO;
    [self setSelectedRange:NSMakeRange(0, 0)];
    [self renewRunsFromStorage];
    [self measure];
    return self;
}

- writeText:(NXStream *)stream
{
    const char * s = [[[self textStorage] string] UTF8String];
    NXWrite(stream, s, strlen(s));
    return self;
}

- writeRichText:(NXStream *)stream
{
    NSData * rtf = [self RTFFromRange:NSMakeRange(0, [[self textStorage] length])];
    NXWrite(stream, [rtf bytes], [rtf length]);
    return self;
}


//	Layout controls
//	---------------

- setMonoFont:(BOOL)flag
{
    tFlags.monoFont = flag;
    [self setRichText:!flag];
    return self;
}

- setNoWrap
{
    tFlags.noWrap = 1;
    [[self textContainer] setWidthTracksTextView:NO];
    [[self textContainer] setContainerSize:NSMakeSize(1.0e7, 1.0e7)];
    [self setHorizontallyResizable:YES];
    return self;
}

- setCharWrap:(BOOL)flag
{
    NSTextContainer * tc = [self textContainer];
    tFlags.noWrap = 0;
    tFlags.charWrap = flag;
    [tc setLineBreakMode:flag ? NSLineBreakByCharWrapping : NSLineBreakByWordWrapping];
    [tc setContainerSize:NSMakeSize([self frame].size.width, 1.0e7)];
    [tc setWidthTracksTextView:YES];
    return self;
}

- setVertResizable:(BOOL)flag	{ [self setVerticallyResizable:flag]; return self; }
- setHorizResizable:(BOOL)flag	{ [self setHorizontallyResizable:flag]; return self; }

- sizeTo:(NXCoord)width :(NXCoord)height
{
    [self setFrameSize:NSMakeSize(width, height)];
    return self;
}

- printPSCode:sender
{
    [[NSPrintOperation printOperationWithView:self] runOperation];
    return self;
}


//	NeXT-style delegate messages
//	----------------------------
//
//	NeXT told the delegate textWillChange: and textDidChange: once, at the
//	first change after tFlags.changeState was cleared. HyperText clears it
//	when a document is loaded or saved.

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)range
	replacementString:(NSString *)string
{
    if (!tFlags.changeState && [delegate respondsToSelector:@selector(textWillChange:)])
	return ![delegate textWillChange:self];	/* NO means "go ahead" (sic) */
    return YES;
}

- (void)textDidChange:(NSNotification *)notification
{
    if (!tFlags.changeState) {
	tFlags.changeState = 1;
	if ([delegate respondsToSelector:@selector(textDidChange:)])
	    [delegate textDidChange:self];
    }
}

@end
