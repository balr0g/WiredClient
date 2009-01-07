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

@end


@implementation WCConnectionController(Private)

- (void)_WC_windowWillClose:(NSNotification *)notification {
	if(!_singleton && [notification object] == [self window])
		[self autorelease];
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

	_name			= [name retain];
	_connection		= connection;
	_singleton		= singleton;
	
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

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_WC_windowWillClose:)
			   name:NSWindowWillCloseNotification];
	
	[self themeDidChange:[[self connection] theme]];
	[self validate];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	if(_singleton) {
		[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:NSStringFromClass([self class])]
									   restoreSize:YES
										visibility:YES];
	}
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	if(_singleton)
		[windowTemplate setObject:[[self window] propertiesDictionary] forKey:NSStringFromClass([self class])];
}



- (void)themeDidChange:(NSDictionary *)theme {
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
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
	[self validate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	if(_singleton)
		[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self validate];
}



#pragma mark -

- (NSString *)name {
	return _name;
}



- (WCServerConnection *)connection {
	return _connection;
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

@end
