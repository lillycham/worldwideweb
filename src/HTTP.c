/*	HyperText Tranfer Protocol	- Client implementation		HTTP.c
**	==========================
*/

/*	Module parameters:
**	-----------------
**
**  These may be undefined and redefined by syspec.h
*/
#include "HTParse.h"
#include "HTUtils.h"
#include "tcp.h"
#include "HTTCP.h"

/*	Port: which version of HTTP to speak
**	-----------------------------------
**
**	TBL's client sent "GET path", the whole of HTTP/0.9. Servers now pick
**	the site from a Host: header, so a bare GET usually reaches the wrong
**	site (info.cern.ch then gives "404 - Not found"). By default the port
**	sends an HTTP/1.0 request with a Host: header instead. Set the default
**	HTTP09 to YES to send the original request:
**
**	    defaults write ch.cern.info.WorldWideWeb HTTP09 YES
*/
PUBLIC int HTTP_Version09 = 0;


/*		Open Socket for reading from HTTP Server	HTTP_get()
**		========================================
**
**	Given a hypertext address, this routine opens a socket to the server.
**
** On entry,
**	arg	is the hypertext reference of the article to be loaded.
** On exit,
**	returns	>=0	If no error, a good socket number
**		<0	Error.
**
**	The socket must be closed by the caller after the document has been
**	read.
**
*/
#ifdef __STDC__
int HTTP_Get(const char * arg)
#else
int HTTP_Get(arg)
    char * arg;
#endif
{
    int s;				/* Socket number for returned data */
    char command[4097];			/* The whole command (Port: was 257) */
    int status;				/* tcp return */
 
    struct sockaddr_in soc_address;	/* Binary network address */
    struct sockaddr_in* sin = &soc_address;

    if (!arg) return -3;			/* Bad if no name sepcified	*/
    if (!*arg) return -2;			/* Bad if name had zero length	*/

/*  Set up defaults:
*/
    sin->sin_family = AF_INET;	    		/* Family, host order  */
    sin->sin_port = htons(TCP_PORT);	    	/* Default: new port,    */

    if (TRACE) printf("HTTPAccess: Looking for %s\n", arg);

/* Get node name and optional port number:
*/
    {
	char *p1 = HTParse(arg, "", PARSE_HOST);
	HTParseInet(sin, p1);
        free(p1);
    }
    
/* We will ask that node for the document, omitting the host name & anchor.
*/        
    strcpy(command, "GET ");
    {
	char * p1 = HTParse(arg, "", PARSE_PATH|PARSE_PUNCTUATION);
	strlcat(command, *p1 ? p1 : "/", sizeof(command) - 512); /* Port: bounded (room
					** for the header lines), and "/" for an empty path, as
					** for http://cat-v.org (was "GET " alone) */
	free(p1);
    }
    if (HTTP_Version09) {
	strcat(command, "\r\n");	/* Port: was "\n". The HTTP/0.9 spec asks for
					** CR LF, and servers now refuse a bare LF. */
    } else {				/* Port: HTTP/1.0 with Host:, see above */
	char * host = HTParse(arg, "", PARSE_HOST);
	snprintf(command + strlen(command), sizeof(command) - strlen(command),
	    " HTTP/1.0\r\nHost: %s\r\nUser-Agent: WorldWideWeb/0.15\r\n"
	    "Accept: text/html, text/plain, */*\r\n\r\n", host);
	free(host);
    }
	    
   
/*	Now, let's get a socket set up from the server for the sgml data:
*/      
    s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    status = HTDoConnect(	/* Port: was connect() */
		s, (struct sockaddr*)&soc_address, sizeof(soc_address));
    if (status<0){
	if (TRACE) printf("HTTPAccess: Unable to connect to remote host for `%s'.\n",
	    arg);
	return HTInetStatus("connect");
    }
    
    if (TRACE) printf("HTTP connected, socket %d\n", s);
    if (TRACE) printf("HTTP writting command `%s' to socket %d\n", command, s);
    
#ifdef NOT_ASCII
    {
    	char * p;
	for(p = command; *p; p++) {
	    *p = TOASCII(*p);
	}
    }
#endif

    status = NETWRITE(s, command, strlen(command));
    if (status<0){
	if (TRACE) printf("HTTPAccess: Unable to send command.\n");
	    return HTInetStatus("send");
    }

/*	Port: an HTTP/1.0 server answers with a status line and headers before
**	the document. Skip them, so that the caller reads the document as it
**	did from an HTTP/0.9 server. (A server which answers without a status
**	line is left alone.)
*/
    if (!HTTP_Version09) {
	char peek[5];
	if (recv(s, peek, 5, MSG_PEEK | MSG_WAITALL) == 5
	&&  strncmp(peek, "HTTP/", 5) == 0) {
	    char c;
	    int newlines = 0;		/* Consecutive line ends seen */
	    if (TRACE) printf("HTTP: Response header:\n");
	    while (newlines < 2 && NETREAD(s, &c, 1) == 1) {
		if (TRACE) putchar(c);
		if (c == '\n') newlines++;
		else if (c != '\r') newlines = 0;
	    }
	}
    }

    return s;			/* Good return */
}
