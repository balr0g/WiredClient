/* $Id$ */

/*
 *  Copyright (c) 2008 Axel Andersson
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

#import "NSAlert-WCAdditions.h"
#import "WCConnect.h"
#import "WCServerConnection.h"

@interface WCConnect(Private)

- (id)_initConnectWithURL:(WIURL *)url bookmark:(NSDictionary *)bookmark;

@end


@implementation WCConnect(Private)

- (id)_initConnectWithURL:(WIURL *)url bookmark:(NSDictionary *)bookmark {
	NSDictionary		*theme;
	
	self = [super initWithWindowNibName:@"Connect"];
	
	_url = [url retain];

	_connection = [[WCServerConnection connection] retain];
	[_connection setURL:url];
	[_connection setBookmark:bookmark];
	
	theme = [WCSettings themeWithIdentifier:[bookmark objectForKey:WCBookmarksTheme]];
	
	if(!theme)
		theme = [WCSettings themeWithIdentifier:[WCSettings objectForKey:WCTheme]];
	
	[_connection setTheme:theme];
	
	[_connection addObserver:self
					selector:@selector(linkConnectionDidClose:)
						name:WCLinkConnectionDidClose];
	
	[_connection addObserver:self
					selector:@selector(linkConnectionDidTerminate:)
						name:WCLinkConnectionDidTerminate];
	
	[_connection addObserver:self
					selector:@selector(linkConnectionLoggedIn:)
						name:WCLinkConnectionLoggedIn];
	
	[self window];
	
	return self;
}

@end




@implementation WCConnect

+ (id)connect {
	return [[self alloc] _initConnectWithURL:NULL bookmark:NULL];
}



+ (id)connectWithURL:(WIURL *)url bookmark:(NSDictionary *)bookmark {
	return [[self alloc] _initConnectWithURL:url bookmark:bookmark];
}



- (void)dealloc {
	[_connection removeObserver:self];

	[_url release];
	[_connection release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
    [self setShouldCascadeWindows:YES];
    [self setWindowFrameAutosaveName:@"Connect"];

	if([_url hostpair])
		[_addressTextField setStringValue:[_url hostpair]];
	
	if([_url user])
		[_loginTextField setStringValue:[_url user]];
	
	if([_url password])
		[_passwordTextField setStringValue:[_url password]];
}



- (void)windowWillClose:(NSNotification *)notification {
	if(!_dismissingWindow) {
		[_connection removeObserver:self name:WCLinkConnectionDidTerminate];
		[_connection terminate];
	}

	[self autorelease];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	if([_connection error]) {
		[self showWindow:self];
		[[[_connection error] alert] beginSheetModalForWindow:[self window]];
	}
	
	[_progressIndicator stopAnimation:self];
	[_connectButton setEnabled:YES];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;

	[self close];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	if([notification object] != _connection)
		return;

	_dismissingWindow = YES;
	
	[self close];
}



#pragma mark -

- (IBAction)connect:(id)sender {
	WIURL		*url;
	
	url = [WIURL URLWithScheme:@"wiredp7" hostpair:[_addressTextField stringValue]];
	[url setUser:[_loginTextField stringValue]];
	[url setPassword:[_passwordTextField stringValue]];
	
	[_connectButton setEnabled:NO];
	[_progressIndicator startAnimation:self];
	
	[_connection setURL:url];
	[_connection connect];
}

@end
