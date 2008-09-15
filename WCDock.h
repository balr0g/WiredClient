/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#define WCServerConnectionPboardType	@"WCServerConnectionPboardType"


@class WCServerConnection;

@interface WCDock : WIWindowController {
	IBOutlet NSTextField				*_statusTextField;
	
	IBOutlet WITableView				*_dockTableView;
	IBOutlet NSTableColumn				*_nameTableColumn;
	IBOutlet NSTableColumn				*_usersTableColumn;
	IBOutlet NSTableColumn				*_statusTableColumn;
	
	IBOutlet NSMenuItem					*_disconnectMenuItem;
	
	IBOutlet NSButton					*_openButton;
	IBOutlet NSButton					*_hideButton;
	
	NSMutableArray						*_shownConnections;
	
	NSImage								*_connectedImage, *_disconnectedImage;
	NSImage								*_bookmarkImage;
	NSImage								*_postsImage;
	NSImage								*_messagesImage;
}

+ (WCDock *)dock;

- (void)openConnection:(WCServerConnection *)connection;
- (WCServerConnection *)connectionWithURL:(WIURL *)url;
- (WCServerConnection *)connectionAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfConnection:(WCServerConnection *)connection;
- (NSUInteger)connectedConnections;

- (IBAction)open:(id)sender;
- (IBAction)hide:(id)sender;
- (IBAction)addBookmark:(id)sender;
- (IBAction)disconnect:(id)sender;
- (IBAction)hideConnection:(id)sender;
- (IBAction)nextConnection:(id)sender;
- (IBAction)previousConnection:(id)sender;
- (IBAction)makeLayoutDefault:(id)sender;
- (IBAction)restoreLayoutToDefault:(id)sender;
- (IBAction)restoreAllLayoutsToDefault:(id)sender;

@end
