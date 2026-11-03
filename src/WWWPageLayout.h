/*		Page layout subclass
**		--------------------
**
** History
**	14 Mar 91	Based on the DrawPageLayout class in the Draw example application
**
*/

#import <appkit/PageLayout.h>

@interface WWWPageLayout : PageLayout
{
    id leftMargin;
    id rightMargin;
    id topMargin;
    id bottomMargin;
}

/* Methods overridden from superclass */

- pickedUnits:sender;
- readPrintInfo;
- writePrintInfo;

/* NIB outlet setting methods (Port: declared, so that the compiler does not
** take NSPrintInfo's setLeftMargin: and so on, which take a number) */

- setTopBotForm:anObject;
- setSideForm:anObject;
- setLeftMargin:anObject;
- setRightMargin:anObject;
- setTopMargin:anObject;
- setBottomMargin:anObject;

@end


