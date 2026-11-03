/*	Headless test of the HTML reader and writer		htmltest.m
**	===========================================
**
**	Reads each document given (a file name, or an http: address fetched
**	with TBL's HTTP_Get) through HyperText's readSGML:, prints the text
**	with its styles and anchors, and writes it back with writeSGML:.
**	No window is opened.
**
**	Usage: htmltest [-w] file-or-address ...   (-w: print the HTML written back)
*/

#import "HyperText.h"
#import "Anchor.h"
#import "StyleToy.h"
#import "HTStyle.h"
#import "HTTP.h"
#import "HTUtils.h"

extern char * appDirectory;
extern HTStyleSheet * styleSheet;

static const char * styleName(void * para)
{
    HTStyle * s;
    for (s = styleSheet->styles; s; s = s->next)
	if (s->paragraph == para) return s->name;
    return para ? "?" : "-";
}

static void show(HyperText * HT)
{
    NXRun * r = HT->theRuns->runs;
    int n = HT->theRuns->chunk.used / sizeof(NXRun);
    NSString * text = [[HT textStorage] string];
    int i, pos = 0;
    printf("title: %s\nlength: %d, runs: %d, index: %s\n",
	[[[HT window] title] UTF8String] ?: "(no window)", HT->textLength, n,
	[HT isIndex] ? "yes" : "no");
    for (i = 0; i < n; i++, r++) {
	NSString * s = [text substringWithRange:NSMakeRange(pos, MIN(r->chars, (int)[text length] - pos))];
	Anchor * a = r->info;
	s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
	if ([s length] > 60) s = [[s substringToIndex:57] stringByAppendingString:@"..."];
	printf("  %-9s %-22s %s%s%s \"%s\"\n", styleName(r->paraStyle),
	    NXFontName(r->font), r->rFlags.underline ? "_" : " ",
	    a ? [a address] : "", a && [a destination] ? " ->" : "",
	    [s UTF8String]);
	if (a && [a destination]) printf("%46s %s\n", "", [[a destination] fullAddress]);
	pos += r->chars;
    }
}

int main(int argc, char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    BOOL writeBack = NO;
    int i;
    appDirectory = "original/NextStep/Implementation/WorldWideWeb.app/";
    if (getenv("WWW_TRACE")) WWW_TraceFlag = 1;
    [NSApplication sharedApplication];		/* No windows, no activation */
    [StyleToy new];				/* Loads default.style */

    for (i = 1; i < argc; i++) {
	NXStream * s;
	Anchor * a;
	HyperText * HT;
	if (strcmp(argv[i], "-w") == 0) { writeBack = YES; continue; }
	printf("=== %s\n", argv[i]);
	if (strncmp(argv[i], "http:", 5) == 0) {
	    int sock = HTTP_Get(argv[i]);
	    if (sock < 0) { printf("HTTP_Get failed: %d\n", sock); continue; }
	    s = NXOpenFile(sock, NX_READONLY);
	} else {
	    s = NXMapFile(argv[i], NX_READONLY);
	    if (!s) { printf("cannot open\n"); continue; }
	}
	a = [Anchor newAddress:argv[i]];
	HT = [HyperText newAnchor:a Server:nil];
	[HT readSGML:s diagnostic:0];
	NXClose(s);
	show(HT);
	if (writeBack) {
	    NXStream * out = NXOpenMemory(NULL, 0, NX_WRITEONLY);
	    [HT writeSGML:out relativeTo:argv[i]];
	    printf("--- written back:\n");
	    fwrite(out->buf, 1, out->len, stdout);
	    NXClose(out);
	}
    }
    [pool release];
    return 0;
}
