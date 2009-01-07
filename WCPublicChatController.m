/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "WCAccount.h"
#import "WCChatWindow.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCPublicChatController.h"
#import "WCServer.h"
#import "WCUser.h"

@interface WCPublicChatController(Private)

- (id)_initPublicChatControllerWithConnection:(WCServerConnection *)connection;

@end


@implementation WCPublicChatController(Private)

- (id)_initPublicChatControllerWithConnection:(WCServerConnection *)connection {
	self = [super init];
	
	[NSBundle loadNibNamed:@"PublicChat" owner:self];
	
	_loadedNib = YES;
	
	[self setConnection:connection];
	
	return self;
}

@end



@implementation WCPublicChatController

+ (id)publicChatControllerWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initPublicChatControllerWithConnection:connection] autorelease];
}



- (void)dealloc {
	if(_loadedNib) {
	}
	
	[super dealloc];
}



#pragma mark -

- (void)awakeFromNib {
	[super awakeFromNib];
}



#pragma mark -

- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.chat.join_chat" spec:WCP7Spec];
	[message setUInt32:[self chatID] forName:@"wired.chat.id"];
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredChatJoinChatReply:)];
	
	[[WCPublicChat publicChat] selectChatController:self];
	[[WCPublicChat publicChat] showWindow:self];
	
	[super linkConnectionLoggedIn:notification];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	[super linkConnectionDidTerminate:notification];

	[self autorelease];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[WCPublicChat publicChat] addChatController:self];
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

//	[[[self window] toolbar] validateVisibleItems];

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



#pragma mark -

- (void)setConnection:(WCServerConnection *)connection {
	[super setConnection:connection];
	
	[_connection addObserver:self
					selector:@selector(serverConnectionServerInfoDidChange:)
						name:WCServerConnectionServerInfoDidChangeNotification];
	
	[_connection addObserver:self selector:@selector(wiredChatInvitation:) messageName:@"wired.chat.invitation"];
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
	   modalForWindow:[_userListSplitView window]
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

		if([_banMessagePopUpButton tagOfSelectedItem] > 0) {
			[message setDate:[NSDate dateWithTimeIntervalSinceNow:[_banMessagePopUpButton tagOfSelectedItem]]
					 forName:@"wired.banlist.expiration_date"];
		}
		
		[[self connection] sendMessage:message];
	}

	[user release];

	[_banMessagePanel close];
	[_banMessageTextField setStringValue:@""];
}



#pragma mark -

- (void)joinChat:(id)sender {
	WCPrivateChat	*chat;

	chat = [WCPrivateChat privateChatWithConnection:[self connection] chatID:[sender tag]];
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
