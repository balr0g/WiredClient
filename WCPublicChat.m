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

#import "NSAlert-WCAdditions.h"
#import "WCAccount.h"
#import "WCApplicationController.h"
#import "WCFile.h"
#import "WCFiles.h"
#import "WCNews.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCServer.h"
#import "WCServerConnection.h"
#import "WCServerInfo.h"
#import "WCUser.h"

@interface WCPublicChat(Private)

- (id)_initPublicChatWithConnection:(WCServerConnection *)connection;

- (void)_showChatWindow;
- (void)_updateNewsIcon;

@end


@implementation WCPublicChat(Private)

- (id)_initPublicChatWithConnection:(WCServerConnection *)connection {
	self = [super initChatWithConnection:connection
						   windowNibName:@"PublicChat"
									name:NSLS(@"Chat", @"Chat window title")
							   singleton:YES];

	[[self connection] addObserver:self
						  selector:@selector(newsDidChangePosts:)
							  name:WCNewsDidAddPost];
	
	[[self connection] addObserver:self
						  selector:@selector(newsDidChangePosts:)
							  name:WCNewsDidReadPost];
	
	[[self connection] addObserver:self selector:@selector(wiredChatInvitation:) messageName:@"wired.chat.invitation"];
	
	[self window];
	
	return self;
}



#pragma mark -

- (void)_showChatWindow {
	if(![self isHidden])
		[self showWindow:self];
}



- (void)_updateNewsIcon {
	NSToolbarItem	*item;
	NSUInteger		count;
	
	count = [[[self connection] news] numberOfUnreadPosts];

	item = [[[self window] toolbar] itemWithIdentifier:@"News"];
	[item setImage:[[NSImage imageNamed:@"News"] badgedImageWithInt:count]];
}

@end



@implementation WCPublicChat

+ (id)publicChatWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initPublicChatWithConnection:connection] autorelease];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar		*toolbar;
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"PublicChat"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];
	
	[super windowDidLoad];
}




- (BOOL)windowShouldClose:(id)sender {
	return [self beginConfirmDisconnectSheetModalForWindow:[self window]
											 modalDelegate:self
											didEndSelector:@selector(terminateSheetDidEnd:returnCode:contextInfo:)
											   contextInfo:NULL];
}



- (void)windowWillClose:(NSNotification *)notification {
	[[self connection] terminate];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:NSStringFromClass([self class])]
								   restoreSize:YES
									visibility:_isShown ? ![self isHidden] : NO];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:NSStringFromClass([self class])];
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	NSButton		*button;
	
	if([identifier isEqualToString:@"Banner"]) {
		button = [[[NSButton alloc] init] autorelease];
		[button setFrame:NSMakeRect(0.0, 0.0, 32.0, 32.0)];
		[button setBordered:NO];
		[button setImage:[NSImage imageNamed:@"Banner"]];
		
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Banner", @"Banner toolbar item")
												content:button
												 target:self
												 action:@selector(banner:)];
	}
	else if([identifier isEqualToString:@"News"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"News", @"News toolbar item")
												content:[NSImage imageNamed:@"News"]
												 target:self
												 action:@selector(news:)];
	}
	else if([identifier isEqualToString:@"Messages"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Messages", @"Messages toolbar item")
												content:[NSImage imageNamed:@"Messages"]
												 target:[WCApplicationController sharedController]
												 action:@selector(messages:)];
	}
	else if([identifier isEqualToString:@"Files"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Files", @"Files toolbar item")
												content:[NSImage imageNamed:@"Folder"]
												 target:self
												 action:@selector(files:)];
	}
	else if([identifier isEqualToString:@"Search"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Search", @"Search toolbar item")
												content:[NSImage imageNamed:@"Search"]
												 target:[WCApplicationController sharedController]
												 action:@selector(search:)];
	}
	else if([identifier isEqualToString:@"Transfers"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Transfers", @"Transfers toolbar item")
												content:[NSImage imageNamed:@"Transfers"]
												 target:[WCApplicationController sharedController]
												 action:@selector(transfers:)];
	}
	else if([identifier isEqualToString:@"Accounts"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Accounts", @"Accounts toolbar item")
												content:[NSImage imageNamed:@"Accounts"]
												 target:self
												 action:@selector(accounts:)];
	}
	else if([identifier isEqualToString:@"Administration"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Administration", @"Administration toolbar item")
												content:[NSImage imageNamed:@"Settings"]
												 target:self
												 action:@selector(administration:)];
	}
	else if([identifier isEqualToString:@"Console"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Console", @"Console toolbar item")
												content:[NSImage imageNamed:@"Console"]
												 target:self
												 action:@selector(console:)];
	}
	else if([identifier isEqualToString:@"Reconnect"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reconnect", @"Disconnect toolbar item")
												content:[NSImage imageNamed:@"Reconnect"]
												 target:self
												 action:@selector(reconnect:)];
	}
	else if([identifier isEqualToString:@"Disconnect"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Disconnect", @"Disconnect toolbar item")
												content:[NSImage imageNamed:@"Disconnect"]
												 target:self
												 action:@selector(disconnect:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Banner",
		NSToolbarSpaceItemIdentifier,
		@"News",
		@"Messages",
		@"Files",
		@"Search",
		@"Transfers",
		@"Accounts",
		@"Administration",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"Reconnect",
		@"Disconnect",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Banner",
		@"News",
		@"Messages",
		@"Files",
		@"Search",
		@"Transfers",
		@"Accounts",
		@"Administration",
#ifndef RELEASE
		@"Console",
#endif
		@"Reconnect",
		@"Disconnect",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	NSString	*reason;
	WCError		*error;
	
	[[self window] setTitle:[[self connection] name] withSubtitle:[NSSWF:@"%@ %C %@",
		NSLS(@"Chat", @"Chat window title"),
		0x2014,
		NSLS(@"Disconnected", "Chat window title")]];
	
	error = [[self connection] error];
	reason = [error localizedFailureReason];
		
	if([reason length] > 0)
		reason = [reason substringWithRange:NSMakeRange(0, [reason length] - 1)];

	if([[self connection] isReconnecting]) {
		[self printEvent:reason];
	} else {
		if([[self window] isMiniaturized])
			[self showWindow:self];
		
		if([[self window] isVisible]) {
			if(![WCSettings boolForKey:WCAutoReconnect] && ![[[self connection] bookmark] boolForKey:WCBookmarksAutoReconnect]) {
				if(![[self connection] isDisconnecting]) {
					[self printEvent:[NSSWF:NSLS(@"Lost connection to %@: %@", @"Disconnected chat message (server, error)"),
						[[self connection] name], reason]];
				}
			}
		}
	}
	
	[super linkConnectionDidClose:notification];
}



- (void)serverConnectionDidTerminate:(NSNotification *)notification {
	[_userListTableView setDataSource:NULL];
	
	[super linkConnectionDidTerminate:notification];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	WIP7Message		*message;
	
	[super linkConnectionLoggedIn:notification];
	
	message = [WIP7Message messageWithName:@"wired.chat.join_chat" spec:WCP7Spec];
	[message setUInt32:[self chatID] forName:@"wired.chat.id"];
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredChatJoinChatReply:)];

	[self performSelector:@selector(_showChatWindow) afterDelay:0.0];
	
	_isShown = YES;
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	NSToolbarItem	*item;
	NSImage			*image;
	NSSize			size;

	item = [[[self window] toolbar] itemWithIdentifier:@"Banner"];
	[item setLabel:[[self connection] name]];
	[item setPaletteLabel:[[self connection] name]];
	[item setToolTip:[[self connection] name]];
	
	image = [[[self connection] server] banner];
	
	if(image) {
		[(NSButton *) [item view] setImage:image];

		size = [image size];

		if(size.width <= 200.0 && size.height <= 32.0) {
			[item setMinSize:size];
			[item setMaxSize:size];
		} else {
			[item setMinSize:NSMakeSize(32.0 * (size.width / size.height), 32.0)];
			[item setMaxSize:NSMakeSize(32.0 * (size.width / size.height), 32.0)];
		}
	} else {
		[(NSButton *) [item view] setImage:[NSImage imageNamed:@"Banner"]];
		
		size = NSMakeSize(32.0, 32.0);
		
		[item setMinSize:size];
		[item setMaxSize:size];
	}

	[super serverConnectionServerInfoDidChange:notification];
}



- (void)wiredChatInvitation:(WIP7Message *)message {
	NSEnumerator	*enumerator;
	NSString		*title, *description;
	NSPanel			*panel;
	NSControl		*control;
	WCUser			*user;
	NSUInteger		i = 0;
	WIP7UInt32		uid, cid;

	[message getUInt32:&cid forName:@"wired.chat.id"];
	[message getUInt32:&uid forName:@"wired.user.id"];

	user = [self userWithUserID:uid];

	if(!user || [user isIgnored])
		return;

	title = [NSSWF:
		NSLS(@"%@ has invited you to a private chat.", @"Private chat invite dialog title (nick)"),
		[user nick]];
	description	= [NSSWF:
		NSLS(@"Join to open a separate private chat with %@.", @"Private chat invite dialog description (nick)"),
		[user nick]];
	panel = NSGetAlertPanel(title, description,
		NSLS(@"Join", @"Private chat invite button title"),
		NSLS(@"Ignore", @"Private chat invite button title"),
		NSLS(@"Decline", @"Private chat invite button title"));

	enumerator = [[[panel contentView] subviews] objectEnumerator];

	while((control = [enumerator nextObject])) {
		if([control isKindOfClass:[NSButton class]]) {
			[control setTarget:self];
			[control setTag:cid];

			switch(i++) {
				case 0:
					[control setAction:@selector(joinChat:)];
					break;

				case 1:
					[control setAction:@selector(ignoreChat:)];
					break;

				case 2:
					[control setAction:@selector(declineChat:)];
					break;
			}
		}
	}

	[panel makeKeyAndOrderFront:self];

	[[self connection] triggerEvent:WCEventsChatInvitationReceived info1:user];
}



- (void)newsDidChangePosts:(NSNotification *)notification {
	[self performSelector:@selector(_updateNewsIcon) withObject:NULL afterDelay:0.0];
}



- (void)terminateSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn)
		[self close];
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
	if(splitView == _userListSplitView)
		return proposedMax - 176.0;
	else if(splitView == _chatSplitView)
		return proposedMax - 15.0;

	return proposedMax;
}



#pragma mark -

- (void)validate {
	BOOL	connected;

	connected = [[self connection] isConnected];

	if([_userListTableView selectedRow] < 0) {
		[_privateChatButton setEnabled:NO];
		[_banButton setEnabled:NO];
	} else {
		[_privateChatButton setEnabled:connected];
		[_banButton setEnabled:([[[self connection] account] userBanUsers] && connected)];
	}

	[[[self window] toolbar] validateVisibleItems];

	[super validate];
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL			selector;
	BOOL		connected;
	
	selector = [item action];
	connected = [[self connection] isConnected];
	
	if(selector == @selector(startPrivateChat:))
		return connected;
	else if(selector == @selector(ban:))
		return ([[[self connection] account] userBanUsers] && connected);
	else if(selector == @selector(setTopic:))
		return ([[[self connection] account] chatSetTopic] && connected);

	return [super validateMenuItem:item];
}



- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	return [super validateAction:[item action]];
}



#pragma mark -

- (IBAction)startPrivateChat:(id)sender {
	WCUser		*user;
	
	user = [self selectedUser];
	
	if([user userID] == [[self connection] userID])
		user = NULL;
	
	[WCPrivateChat privateChatWithConnection:[self connection] inviteUser:user];
}



- (IBAction)ban:(id)sender {
	[NSApp beginSheet:_banMessagePanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(banSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[[self selectedUser] retain]];
}



- (void)banSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	WCUser			*user = contextInfo;

	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.user.ban_user" spec:WCP7Spec];
		[message setUInt32:[user userID] forName:@"wired.user.id"];
		[message setString:[_banMessageTextField stringValue] forName:@"wired.user.disconnect_message"];
		[[self connection] sendMessage:message];
	}

	[user release];

	[_banMessagePanel close];
	[_banMessageTextField setStringValue:@""];
}



#pragma mark -

- (void)joinChat:(id)sender {
	WCPrivateChat	*chat;
	NSUInteger		cid;

	cid = [sender tag];
	chat = [WCPrivateChat privateChatWithConnection:[self connection] chatID:cid];
	[chat showWindow:self];

	[[sender window] orderOut:self];
	NSReleaseAlertPanel([sender window]);
}



- (void)declineChat:(id)sender {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.chat.decline_invitation" spec:WCP7Spec];
	[message setUInt32:[sender tag] forName:@"wired.chat.id"];
	[[self connection] sendMessage:message];

	[[sender window] orderOut:self];
	NSReleaseAlertPanel([sender window]);
}



- (void)ignoreChat:(id)sender {
	[[sender window] orderOut:self];

	NSReleaseAlertPanel([sender window]);
}



- (void)banner:(id)sender {
	[[[self connection] serverInfo] showWindow:self];
}

@end
