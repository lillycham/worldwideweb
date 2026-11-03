/*	Headless test of TBL's FTP client		ftptest.c
**	Usage: ftptest file://host/path   (prints the start of the file)
*/
#include "HTUtils.h"
#include "HTFTP.h"
#include <unistd.h>

extern int WWW_TraceFlag;		/* In HTString.c */

int main(int argc, char ** argv)
{
    char buf[400];
    int s, n;
    if (getenv("WWW_TRACE")) WWW_TraceFlag = 1;
    s = HTFTP_open_file_read(argv[1]);
    printf("HTFTP_open_file_read: %d\n", s);
    if (s < 0) return 1;
    n = read(s, buf, sizeof(buf) - 1);
    if (n > 0) { buf[n] = 0; printf("--- %d bytes:\n%s\n", n, buf); }
    printf("HTFTP_close_file: %d\n", HTFTP_close_file(s));
    return 0;
}
