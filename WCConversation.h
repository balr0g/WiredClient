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

#import "WCServerConnectionObject.h"

@class WCMessage, WCUser;

@interface WCConversation : WCServerConnectionObject {
	NSString					*_name;
	NSMutableArray				*_conversations;
	NSMutableArray				*_messages;
	BOOL						_expandable;
	
	WCUser						*_user;
}

+ (id)rootConversation;
+ (id)conversationWithUser:(WCUser *)user connection:(WCServerConnection *)connection;

- (NSString *)name;
- (BOOL)isExpandable;

- (NSUInteger)numberOfConversations;
- (NSArray *)conversations;
- (WCConversation *)conversationAtIndex:(NSUInteger)index;
- (WCConversation *)conversationForUser:(WCUser *)user connection:(WCServerConnection *)connection;
- (void)addConversations:(NSArray *)conversations;
- (void)addConversation:(WCConversation *)conversation;
- (void)removeConversation:(WCConversation *)conversation;
- (void)removeAllConversations;

- (NSUInteger)numberOfMessages;
- (NSUInteger)numberOfUnreadMessagesForConnection:(WCServerConnection *)connection includeChildConversations:(BOOL)includeChildConversations;
- (NSArray *)messages;
- (NSArray *)unreadMessages;
- (WCMessage *)messageAtIndex:(NSUInteger)index;
- (WCMessage *)previousUnreadMessageStartingAtConversation:(WCConversation *)conversation message:(WCMessage *)message forwardsInMessages:(BOOL)forwardsInMessages;
- (WCMessage *)nextUnreadMessageStartingAtConversation:(WCConversation *)conversation message:(WCMessage *)message forwardsInMessages:(BOOL)forwardsInMessages;
- (void)addMessage:(WCMessage *)message;
- (void)removeMessage:(WCMessage *)message;
- (void)removeAllMessages;

- (void)invalidateForConnection:(WCServerConnection *)connection;
- (void)revalidateForConnection:(WCServerConnection *)connection;
- (void)invalidateForConnection:(WCServerConnection *)connection user:(WCUser *)user;
- (void)revalidateForConnection:(WCServerConnection *)connection user:(WCUser *)user;

@end


@interface WCMessageConversation : WCConversation

@end


@interface WCBroadcastConversation : WCConversation

@end
