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

#import "WCAccount.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCServerConnection.h"
#import "WCUser.h"

@interface WCPrivateChat(Private)

- (id)_initPrivateChatWithConnection:(WCServerConnection *)connection chatID:(NSUInteger)cid inviteUser:(WCUser *)user;

@end


@implementation WCPrivateChat(Private)

- (id)_initPrivateChatWithConnection:(WCServerConnection *)connection chatID:(NSUInteger)cid inviteUser:(WCUser *)user {
	WIP7Message		*message;
	
	self = [super initChatWithConnection:connection
						   windowNibName:@"PrivateChat"
									name:NSLS(@"Private Chat", @"Chat window title")
							   singleton:NO];
	
	_cid = cid;
	_user = [user retain];

	if([self chatID] == 0) {
		message = [WIP7Message messageWithName:@"wired.chat.create_chat" spec:WCP7Spec];
		[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredChatCreateChatReply:)];
	} else {
		message = [WIP7Message messageWithName:@"wired.chat.join_chat" spec:WCP7Spec];
		[message setUInt32:[self chatID] forName:@"wired.chat.id"];
		[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredChatJoinChatReply:)];
	}

	[[self connection] addObserver:self
						  selector:@selector(wiredChatUserDeclineInvitation:)
					   messageName:@"wired.chat.user_decline_invitation"];
	
	[self window];
	
	return self;
}

@end


@implementation WCPrivateChat

+ (id)privateChatWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initPrivateChatWithConnection:connection chatID:0 inviteUser:NULL] autorelease];
}



+ (id)privateChatWithConnection:(WCServerConnection *)connection chatID:(NSUInteger)cid {
	return [[[self alloc] _initPrivateChatWithConnection:connection chatID:cid inviteUser:NULL] autorelease];
}



+ (id)privateChatWithConnection:(WCServerConnection *)connection inviteUser:(WCUser *)user {
	return [[[self alloc] _initPrivateChatWithConnection:connection chatID:0 inviteUser:user] autorelease];
}



+ (id)privateChatWithConnection:(WCServerConnection *)connection chatID:(NSUInteger)cid inviteUser:(WCUser *)user {
	return [[[self alloc] _initPrivateChatWithConnection:connection chatID:0 inviteUser:user] autorelease];
}



#pragma mark -

- (void)dealloc {
	[_user release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Private Chat"];

	[[self window] setTitle:[_connection name] withSubtitle:[self name]];

	[_userListTableView registerForDraggedTypes:[NSArray arrayWithObject:WCUserPboardType]];
	
	[super windowDidLoad];
}



- (void)windowWillClose:(NSNotification *)notification {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.chat.leave_chat" spec:WCP7Spec];
	[message setUInt32:[self chatID] forName:@"wired.chat.id"];
	[[self connection] sendMessage:message];
}



- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[_connection name] withSubtitle:[self name]];
}



- (void)wiredChatCreateChatReply:(WIP7Message *)message {
	WIP7Message		*reply;

	[message getUInt32:&_cid forName:@"wired.chat.id"];
	
	reply = [WIP7Message messageWithName:@"wired.chat.join_chat" spec:WCP7Spec];
	[reply setUInt32:[self chatID] forName:@"wired.chat.id"];
	[[self connection] sendMessage:reply fromObserver:self selector:@selector(wiredChatJoinChatReply:)];

	[self showWindow:self];

}



- (void)wiredChatJoinChatReply:(WIP7Message *)message {
	WIP7Message		*reply;

	[super wiredChatJoinChatReply:message];
	
	if([[message name] isEqualToString:@"wired.chat.user_list.done"]) {
		if(_user) {
			reply = [WIP7Message messageWithName:@"wired.chat.invite_user" spec:WCP7Spec];
			[reply setUInt32:[self chatID] forName:@"wired.chat.id"];
			[reply setUInt32:[_user userID] forName:@"wired.user.id"];
			[[self connection] sendMessage:reply];

			[_user release];
			_user = NULL;
		}
	}
}



- (void)wiredChatUserDeclineInvitation:(WIP7Message *)message {
	WCUser		*user;
	WIP7UInt32	uid, cid;

	[message getUInt32:&cid forName:@"wired.chat.id"];
	
	if(cid != [self chatID])
		return;
	
	[message getUInt32:&uid forName:@"wired.user.id"];

	user = [[[self connection] chat] userWithUserID:uid];
	
	if(!user)
		return;

	[self printEvent:[NSSWF:
		NSLS(@"%@ has declined invitation", @"Private chat decline message (nick)"),
		[user nick]]];
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
	if(splitView == _userListSplitView)
		return proposedMax - 64.0;
	else if(splitView == _chatSplitView)
		return proposedMax - 15.0;

	return proposedMax;
}



#pragma mark -

- (NSUInteger)chatID {
	return _cid;
}



#pragma mark -

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
	if(row >= 0)
		[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];

	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard		*pasteboard;
	WIP7Message			*message;
	NSUInteger			userID;

	pasteboard = [info draggingPasteboard];
	userID = [[pasteboard stringForType:WCUserPboardType] integerValue];

	message = [WIP7Message messageWithName:@"wired.chat.invite_user" spec:WCP7Spec];
	[message setUInt32:[self chatID] forName:@"wired.chat.id"];
	[message setUInt32:userID forName:@"wired.user.id"];
	[[self connection] sendMessage:message];
	
	return YES;
}

@end
