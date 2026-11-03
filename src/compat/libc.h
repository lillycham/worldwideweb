/*	NeXT <libc.h> for modern macOS				compat/libc.h
**	==============================
**
**	NeXTSTEP packaged the Unix headers up into one file. This brings in
**	the same set, so that the original #import <libc.h> lines still work.
*/
#ifndef COMPAT_LIBC_H
#define COMPAT_LIBC_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif
