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

#import "WCConnectionController.h"
#import "WCFile.h"
#import "WCFiles.h"
#import "WCKeychain.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCPublicChat.h"
#import "WCServerConnection.h"
#import "WCSettings.h"

@interface WCConnectionController(Private)

- (void)_loadWindowTemplate;
- (void)_saveWindowTemplate;

@end


@implementation WCConnectionController(Private)

- (void)_loadWindowTemplate {
	NSDictionary	*windowTemplate;
	
	_identifier = [[[self connection] identifier] retain];
	
	windowTemplate = [WCSettings windowTemplateForKey:_identifier];
	
	if(!windowTemplate)
		windowTemplate = [WCSettings windowTemplateForKey:WCWindowTemplatesDefault];
	
	if(windowTemplate)
		_windowTemplate = [[windowTemplate objectForKey:[self windowNibName]] mutableCopy];

	if(!_windowTemplate)
		_windowTemplate = [[NSMutableDictionary alloc] init];
	
	[self windowTemplateShouldLoad:_windowTemplate];
}



- (void)_saveWindowTemplate {
	NSMutableDictionary		*windowTemplate;
	
	if(_windowTemplate) {
		[self windowTemplateShouldSave:_windowTemplate];
		
		windowTemplate = [[WCSettings windowTemplateForKey:_identifier] mutableCopy];
		
		if(!windowTemplate)
			windowTemplate = [[NSMutableDictionary alloc] init];
		
		[windowTemplate setObject:_windowTemplate forKey:[self windowNibName]];
		
		[WCSettings setWindowTemplate:windowTemplate forKey:_identifier];
		
		[windowTemplate release];
	}
}



#pragma mark -

- (void)_WC_applicationWillTerminate:(NSNotification *)notification {
	[self _saveWindowTemplate];
}



- (void)_WC_windowWillClose:(NSNotification *)notification {
	if(!_singleton && [notification object] == [self window]) {
		[self _saveWindowTemplate];
		
		[self autorelease];
	}
}



- (void)_serverConnectionShouldLoadWindowTemplate:(NSNotification *)notification {
	[self _loadWindowTemplate];
}



- (void)_serverConnectionShouldSaveWindowTemplate:(NSNotification *)notification {
	[self _saveWindowTemplate];
}




- (void)_serverConnectionThemeDidChange:(NSNotification *)notification {
	[self themeDidChange:[[self connection] theme]];
}



- (void)_disconnectSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn)
		[[self connection] disconnect];
}

@end


@implementation WCConnectionController

- (id)initWithWindowNibName:(NSString *)nibName connection:(WCServerConnection *)connection singleton:(BOOL)singleton {
	return [self initWithWindowNibName:nibName name:NULL connection:connection singleton:singleton];
}



- (id)initWithWindowNibName:(NSString *)nibName name:(NSString *)name connection:(WCServerConnection *)connection singleton:(BOOL)singleton {
	self = [super initWithWindowNibName:nibName];

	_name = [name retain];
	_connection = connection;
	_singleton = singleton;
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_WC_applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification];

	[_connection addObserver:self
					selector:@selector(linkConnectionDidTerminate:)
						name:WCLinkConnectionDidTerminateNotification];

	[_connection addObserver:self
					selector:@selector(linkConnectionDidClose:)
						name:WCLinkConnectionDidCloseNotification];
	
	[_connection addObserver:self
					selector:@selector(linkConnectionLoggedIn:)
						name:WCLinkConnectionLoggedInNotification];
		
	[_connection addObserver:self
					selector:@selector(serverConnectionServerInfoDidChange:)
						name:WCServerConnectionServerInfoDidChangeNotification];

	[_connection addObserver:self
					selector:@selector(serverConnectionPrivilegesDidChange:)
						name:WCServerConnectionPrivilegesDidChangeNotification];

	[_connection addObserver:self
					selector:@selector(serverConnectionShouldHide:)
						name:WCServerConnectionShouldHideNotification];
	
	[_connection addObserver:self
					selector:@selector(serverConnectionShouldUnhide:)
						name:WCServerConnectionShouldUnhideNotification];

	[_connection addObserver:self
					selector:@selector(_serverConnectionShouldLoadWindowTemplate:)
						name:WCServerConnectionShouldLoadWindowTemplateNotification];

	[_connection addObserver:self
					selector:@selector(_serverConnectionShouldSaveWindowTemplate:)
						name:WCServerConnectionShouldSaveWindowTemplateNotification];

	[_connection addObserver:self
					selector:@selector(_serverConnectionThemeDidChange:)
						name:WCServerConnectionThemeDidChangeNotification];

	if([self respondsToSelector:@selector(serverConnectionWillReconnect:)]) {
		[_connection addObserver:self
						selector:@selector(serverConnectionWillReconnect:)
							name:WCServerConnectionWillReconnectNotification];
	}
	
	[self retain];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_name release];
	[_identifier release];

	[_connection removeObserver:self];
	_connection = NULL;
	
	[_windowTemplate release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_WC_windowWillClose:)
			   name:NSWindowWillCloseNotification];
	
	if(!_singleton)
		[self windowTemplate];
	
	[self themeDidChange:[[self connection] theme]];
	[self validate];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	if(_singleton) {
		[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:NSStringFromClass([self class])]
									   restoreSize:YES
										visibility:![self isHidden]];
	}
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	if(_singleton)
		[windowTemplate setObject:[[self window] propertiesDictionary] forKey:NSStringFromClass([self class])];
}



- (void)themeDidChange:(NSDictionary *)theme {
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	[self _saveWindowTemplate];
	
	if(![self isKindOfClass:[WCPublicChat class]])
		[self close];

	if(_singleton)
		[self autorelease];

	[_connection removeObserver:self];
	_connection = NULL;
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	[self validate];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	if(_singleton)
		[self windowTemplate];
	
	[self validate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	if(_singleton)
		[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self validate];
}



- (void)serverConnectionShouldHide:(NSNotification *)notification {
	NSWindow	*sheet;
		
	_wasVisible = [[self window] isVisible];
	_hidden = YES;
	
	if(_wasVisible) {
		sheet = [[self window] attachedSheet];
		
		if(sheet)
			[NSApp endSheet:sheet returnCode:NSAlertAlternateReturn];
		
		[[self window] orderOut:self];
	}
}



- (void)serverConnectionShouldUnhide:(NSNotification *)notification {
	if(_wasVisible)
		[[self window] orderFront:self];
		
	_hidden = NO;
}



#pragma mark -

- (void)setName:(NSString *)name {
	[name retain];
	[_name release];

	_name = name;
}



- (NSString *)name {
	return _name;
}



- (void)setConnection:(WCServerConnection *)connection {
	[connection retain];
	[_connection release];

	_connection = connection;
}



- (WCServerConnection *)connection {
	return _connection;
}



- (NSDictionary *)windowTemplate {
	if(!_windowTemplate)
		[self _loadWindowTemplate];
	
	return _windowTemplate;
}



- (BOOL)isHidden {
	return _hidden;
}



#pragma mark -

- (BOOL)beginConfirmDisconnectSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)selector contextInfo:(void *)contextInfo {
	if([WCSettings boolForKey:WCConfirmDisconnect] && [[self connection] isConnected]) {
		NSBeginAlertSheet(NSLS(@"Are you sure you want to disconnect?", @"Disconnect dialog title"),
						  NSLS(@"Disconnect", @"Disconnect dialog button"),
						  NSLS(@"Cancel", @"Disconnect dialog button title"),
						  NULL,
						  window,
						  delegate,
						  selector,
						  NULL,
						  contextInfo,
						  NSLS(@"Disconnecting will close any ongoing file transfers.", @"Disconnect dialog description"));
		
		return NO;
	}
	
	return YES;
}



#pragma mark -

- (void)validate {
}



- (BOOL)validateAction:(SEL)selector {
	BOOL		connected;

	if(![self connection])
		return NO;
	
	connected = [[self connection] isConnected];
	
	if(selector == @selector(disconnect:))
		return (connected && ![[self connection] isDisconnecting]);
	else if(selector == @selector(reconnect:))
		return (!connected && ![[self connection] isManuallyReconnecting]);
	else if(selector == @selector(files:) || selector == @selector(postNews:) || selector == @selector(broadcast:))
		return connected;
	
	return YES;
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	return [self validateAction:[item action]];
}



- (IBAction)disconnect:(id)sender {
	if(![[self connection] isDisconnecting]) {
		if([self beginConfirmDisconnectSheetModalForWindow:[[[self connection] chat] window]
											 modalDelegate:self
											didEndSelector:@selector(_disconnectSheetDidEnd:returnCode:contextInfo:)
											   contextInfo:NULL]) {
			[[self connection] disconnect];
		}
	}
}



- (IBAction)reconnect:(id)sender {
	[[self connection] reconnect];
}



- (IBAction)serverInfo:(id)sender {
	[[[self connection] serverInfo] showWindow:self];
}



- (IBAction)chat:(id)sender {
	[[[self connection] chat] showWindow:self];
}



- (IBAction)news:(id)sender {
	[[[self connection] news] showWindow:self];
}



- (IBAction)board:(id)sender {
	[[[self connection] board] showWindow:self];
}



- (IBAction)files:(id)sender {
	[WCFiles filesWithConnection:[self connection] path:[WCFile fileWithRootDirectoryForConnection:[self connection]]];
}



- (IBAction)accounts:(id)sender {
	[[[self connection] accounts] showWindow:self];
}



- (IBAction)administration:(id)sender {
	[[[self connection] administration] showWindow:self];
}



- (IBAction)postNews:(id)sender {
	[[[self connection] news] postNews:self];
}



- (IBAction)broadcast:(id)sender {
	[[WCMessages messages] showBroadcastForConnection:[self connection]];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	NSDictionary		*bookmark;
	NSString			*login, *password;
	WIURL				*url;
	WCServerConnection	*connection;
	
	connection = [self connection];
	url = [connection URL];
	
	if(url) {
		login		= [url user] ? [url user] : @"";
		password	= [url password] ? [url password] : @"";
		bookmark	= [NSDictionary dictionaryWithObjectsAndKeys:
			[connection name],			WCBookmarksName,
			[url hostpair],				WCBookmarksAddress,
			login,						WCBookmarksLogin,
			@"",						WCBookmarksNick,
			@"",						WCBookmarksStatus,
			[NSString UUIDString],		WCBookmarksIdentifier,
			NULL];
		
		[WCSettings addObject:bookmark toArrayForKey:WCBookmarks];
		
		[[WCKeychain keychain] setPassword:password forBookmark:bookmark];

		[connection setBookmark:bookmark];
		[connection postNotificationName:WCServerConnectionShouldSaveWindowTemplateNotification];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChangeNotification];
	}
}



#pragma mark -

- (IBAction)console:(id)sender {
	[[[self connection] console] showWindow:self];
}

@end
