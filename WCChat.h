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

#define WCChatUsersDidChange			@"WCChatUsersDidChange"
#define WCChatSelfWasKicked				@"WCChatSelfWasKicked"
#define WCChatSelfWasBanned				@"WCChatSelfWasBanned"

#define WCUserPboardType				@"WCUserPboardType"


@class WCUser, WCTopic;

@interface WCChat : WCConnectionController {
	IBOutlet WISplitView				*_userListSplitView;

	IBOutlet NSView						*_chatView;
	IBOutlet NSTextField				*_topicTextField;
	IBOutlet NSTextField				*_topicNickTextField;
	IBOutlet WISplitView				*_chatSplitView;
	IBOutlet NSScrollView				*_chatOutputScrollView;
	IBOutlet WITextView					*_chatOutputTextView;
	IBOutlet NSScrollView				*_chatInputScrollView;
	IBOutlet NSTextView					*_chatInputTextView;

	IBOutlet NSView						*_userListView;
	IBOutlet NSButton					*_privateMessageButton;
	IBOutlet NSButton					*_infoButton;
	IBOutlet NSButton					*_kickButton;
	IBOutlet WITableView				*_userListTableView;
	IBOutlet NSTableColumn				*_iconTableColumn;
	IBOutlet NSTableColumn				*_nickTableColumn;

	IBOutlet NSPanel					*_setTopicPanel;
	IBOutlet NSTextView					*_setTopicTextView;

	IBOutlet NSMenu						*_userListMenu;
	IBOutlet NSMenuItem					*_sendPrivateMessageMenuItem;
	IBOutlet NSMenuItem					*_getInfoMenuItem;
	IBOutlet NSMenuItem					*_ignoreMenuItem;
	
	IBOutlet NSPanel					*_kickMessagePanel;
	IBOutlet NSTextField				*_kickMessageTextField;

	IBOutlet NSView						*_saveChatView;
	IBOutlet NSPopUpButton				*_saveChatFileFormatPopUpButton;
	IBOutlet NSPopUpButton				*_saveChatPlainTextEncodingPopUpButton;

	NSMutableArray						*_commandHistory;
	NSUInteger							_currentCommand;
	NSString							*_currentString;

	NSMutableDictionary					*_users;
	NSMutableArray						*_allUsers, *_shownUsers;
	BOOL								_receivedUserList;

	WITextFilter						*_chatFilter;
	WITextFilter						*_topicFilter;
	NSDate								*_timestamp;
	WCTopic								*_topic;
	
	WIDateFormatter						*_timestampDateFormatter;
	WIDateFormatter						*_timestampEveryLineDateFormatter;
	WIDateFormatter						*_topicDateFormatter;
	
	NSMutableDictionary					*_pings;
}


- (id)initChatWithConnection:(WCServerConnection *)connection windowNibName:(NSString *)windowNibName name:(NSString *)name singleton:(BOOL)singleton;

- (void)wiredChatJoinChatReply:(WIP7Message *)message;

- (WCUser *)selectedUser;
- (NSArray *)selectedUsers;
- (NSArray *)users;
- (NSArray *)nicks;
- (WCUser *)userAtIndex:(NSUInteger)index;
- (WCUser *)userWithUserID:(NSUInteger)uid;
- (void)selectUser:(WCUser *)user;
- (NSUInteger)chatID;

- (void)printEvent:(NSString *)message;

- (IBAction)stats:(id)sender;
- (IBAction)saveChat:(id)sender;
- (IBAction)setTopic:(id)sender;
- (IBAction)sendPrivateMessage:(id)sender;
- (IBAction)getInfo:(id)sender;
- (IBAction)kick:(id)sender;
- (IBAction)editAccount:(id)sender;
- (IBAction)ignore:(id)sender;
- (IBAction)unignore:(id)sender;

- (IBAction)fileFormat:(id)sender;

@end
