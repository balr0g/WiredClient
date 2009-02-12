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

#define WCMessagesDidChangeUnreadCountNotification	@"WCMessagesDidChangeUnreadCountNotification"


@class WCSourceSplitView;
@class WCConversation, WCMessageConversation, WCBroadcastConversation, WCUser;

@interface WCMessages : WIWindowController {
	IBOutlet WCSourceSplitView						*_conversationsSplitView;
	IBOutlet NSView									*_conversationsView;
	IBOutlet NSView									*_messagesView;
	IBOutlet WISplitView							*_messagesSplitView;
	IBOutlet NSView									*_messageTopView;
	IBOutlet NSView									*_messageBottomView;
	IBOutlet NSView									*_messageListView;
	IBOutlet NSView									*_messageView;

	IBOutlet NSOutlineView							*_conversationsOutlineView;
	IBOutlet NSTableColumn							*_conversationTableColumn;
	IBOutlet NSTableColumn							*_unreadTableColumn;
	
	IBOutlet WebView								*_messageWebView;
	IBOutlet NSTextView								*_messageTextView2;

	IBOutlet NSPanel								*_broadcastPanel;
	IBOutlet NSTextView								*_broadcastTextView;

	WCConversation									*_conversations;
	WCMessageConversation							*_messageConversations;
	WCBroadcastConversation							*_broadcastConversations;
	WCConversation									*_selectedConversation;
	
	NSFont											*_messageFont;
	NSColor											*_messageColor;
	NSImage											*_conversationIcon;
	
	WIDateFormatter									*_dialogDateFormatter;
	WIDateFormatter									*_messageStatusDateFormatter;
	WIDateFormatter									*_messageTimeDateFormatter;
	
	NSMutableString									*_headerTemplate;
	NSMutableString									*_footerTemplate;
	NSMutableString									*_messageTemplate;
	NSMutableString									*_statusTemplate;
}

+ (id)messages;

- (void)showPrivateMessageToUser:(WCUser *)user;
- (void)showPrivateMessageToUser:(WCUser *)user message:(NSString *)message;
- (void)showBroadcastForConnection:(WCServerConnection *)connection;
- (NSUInteger)numberOfUnreadMessages;
- (NSUInteger)numberOfUnreadMessagesForConnection:(WCServerConnection *)connection;

- (IBAction)reply:(id)sender;
- (IBAction)revealInUserList:(id)sender;
- (IBAction)clearMessages:(id)sender;

@end
