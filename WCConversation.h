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
	NSUInteger					_userID;
	NSMutableArray				*_conversations;
	NSMutableArray				*_messages;
	BOOL						_expandable;
}

+ (id)rootConversation;
+ (id)conversationWithUser:(WCUser *)user connection:(WCServerConnection *)connection;

- (NSString *)name;
- (BOOL)isExpandable;
- (NSUInteger)userID;

- (NSUInteger)numberOfConversations;
- (NSArray *)conversations;
- (id)conversationAtIndex:(NSUInteger)index;
- (id)conversationForUser:(WCUser *)user connection:(WCServerConnection *)connection;
- (void)addConversation:(id)conversation;
- (void)removeConversation:(id)conversation;
- (void)removeAllConversations;

- (NSUInteger)numberOfMessages;
- (NSUInteger)numberOfUnreadMessages;
- (NSUInteger)numberOfUnreadMessagesForConnection:(WCServerConnection *)connection;
- (NSArray *)messages;
- (NSArray *)unreadMessages;
- (id)messageAtIndex:(NSUInteger)index;
- (id)previousUnreadMessageStartingAtConversation:(id)conversation message:(id)message;
- (id)nextUnreadMessageStartingAtConversation:(id)conversation message:(id)message;
- (void)sortMessagesUsingSelector:(SEL)selector;
- (void)addMessage:(id)message;
- (void)removeMessage:(id)message;
- (void)removeAllMessages;
- (void)invalidateMessagesForConnection:(WCServerConnection *)connection;
- (void)revalidateMessagesForConnection:(WCServerConnection *)connection;

@end


@interface WCMessageConversation : WCConversation

@end


@interface WCBroadcastConversation : WCConversation

@end
