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

#import "WCConversation.h"
#import "WCMessage.h"
#import "WCUser.h"

@interface WCConversation(Private)

- (id)_initWithName:(NSString *)name userID:(NSUInteger)userID expandable:(BOOL)expandable connection:(WCServerConnection *)connection;

- (id)_unreadMessageStartingAtConversation:(id)startingConversation message:(id)startingMessage forwards:(BOOL)forwards passed:(BOOL)passed;

@end


@implementation WCConversation(Private)

- (id)_initWithName:(NSString *)name userID:(NSUInteger)userID expandable:(BOOL)expandable connection:(WCServerConnection *)connection {
	self = [self initWithConnection:connection];
	
	_name			= [name retain];
	_userID			= userID;
	_expandable		= expandable;
	
	return self;
}



#pragma mark -

- (id)_unreadMessageStartingAtConversation:(id)startingConversation message:(id)startingMessage forwards:(BOOL)forwards passed:(BOOL)passed {
	WCConversation	*conversation;
	WCMessage		*message;
	NSUInteger		i, count;
	
	count = [_messages count];
	
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:forwards ? i : count - i - 1];
		
		if((startingConversation == NULL || startingConversation == self) &&
		   (startingMessage == NULL || startingMessage == message))
			passed = YES;
		
		if(passed && ![message isRead])
			return message;
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++) {
		conversation = [_conversations objectAtIndex:forwards ? i : count - i - 1];
		message = [conversation _unreadMessageStartingAtConversation:startingConversation
															 message:startingMessage
															forwards:forwards
															  passed:passed];
		
		if(message)
			return message;
	}
	
	return NULL;
}

@end



@implementation WCConversation

+ (id)rootConversation {
	return [[[self alloc] _initWithName:@"<root>" userID:0 expandable:YES connection:NULL] autorelease];
}



+ (id)conversationWithUser:(WCUser *)user connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithName:[user nick] userID:[user userID] expandable:NO connection:connection] autorelease];
}



- (id)initWithConnection:(WCServerConnection *)connection {
	self = [super initWithConnection:connection];
	
	_conversations	= [[NSMutableArray alloc] init];
	_messages		= [[NSMutableArray alloc] init];
	
	return self;
}



- (void)dealloc {
	[_conversations release];
	[_name release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)name {
	return _name;
}



- (BOOL)isExpandable {
	return _expandable;
}



- (NSUInteger)userID {
	return _userID;
}



#pragma mark -

- (NSUInteger)numberOfConversations {
	return [_conversations count];
}



- (NSArray *)conversations {
	return _conversations;
}



- (id)conversationAtIndex:(NSUInteger)index {
	return [_conversations objectAtIndex:index];
}



- (id)conversationForUser:(WCUser *)user connection:(WCServerConnection *)connection {
	WCConversation		*conversation;
	NSUInteger			i, count;

	count = [_conversations count];
	
	for(i = 0; i < count; i++) {
		conversation = [_conversations objectAtIndex:i];
		
		if([conversation userID] == [user userID] && [conversation connection] == connection)
			return conversation;
	}
	
	return NULL;
}



- (void)addConversation:(id)conversation {
	[_conversations addObject:conversation];
}



- (void)removeConversation:(id)conversation {
	[_conversations removeObject:conversation];
}



- (void)removeAllConversations {
	[_conversations removeAllObjects];
}



#pragma mark -

- (NSUInteger)numberOfMessages {
	return [_messages count];
}



- (NSUInteger)numberOfUnreadMessages {
	return [self numberOfUnreadMessagesForConnection:NULL];
}



- (NSUInteger)numberOfUnreadMessagesForConnection:(WCServerConnection *)connection {
	WCMessage		*message;
	NSUInteger		i, count, unread;
	
	unread = 0;
	count = [_messages count];
	
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:i];
		
		if(!connection || [message connection] == connection) {
			if(![message isRead])
				unread++;
		}
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++)
		unread += [[_conversations objectAtIndex:i] numberOfUnreadMessages];
	
	return unread;
}



- (NSArray *)messages {
	return _messages;
}



- (NSArray *)unreadMessages {
	NSMutableArray	*messages;
	WCMessage		*message;
	NSUInteger		i, count;
	
	messages = [NSMutableArray array];
	count = [_messages count];
		
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:i];
		
		if(![message isRead])
			[messages addObject:message];
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++)
		[messages addObjectsFromArray:[[_conversations objectAtIndex:i] unreadMessages]];

	return messages;
}



- (id)messageAtIndex:(NSUInteger)index {
	return [_messages objectAtIndex:index];
}



- (id)previousUnreadMessageStartingAtConversation:(id)conversation message:(id)message {
	return [self _unreadMessageStartingAtConversation:conversation message:message forwards:NO passed:NO];
}



- (id)nextUnreadMessageStartingAtConversation:(id)conversation message:(id)message {
	return [self _unreadMessageStartingAtConversation:conversation message:message forwards:YES passed:NO];
}



- (void)sortMessagesUsingSelector:(SEL)selector {
	[_messages sortUsingSelector:selector];
}



- (void)addMessage:(id)_message {
	[_messages addObject:_message];
}



- (void)removeMessage:(id)_message {
	[_messages removeObject:_message];
}



- (void)removeAllMessages {
	[_messages removeAllObjects];
}



- (void)invalidateMessagesForConnection:(WCServerConnection *)connection {
	WCMessage		*message;
	NSUInteger		i, count;
	
	count = [_messages count];
		
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:i];
		
		if([message connection] == connection)
			[message setConnection:NULL];
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++)
		[[_conversations objectAtIndex:i] invalidateMessagesForConnection:connection];
}



- (void)revalidateMessagesForConnection:(WCServerConnection *)connection {
	WCMessage		*message;
	NSUInteger		i, count;
	
	count = [_messages count];
		
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:i];
		
		if([message belongsToConnection:connection])
			[message setConnection:connection];
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++)
		[[_conversations objectAtIndex:i] invalidateMessagesForConnection:connection];
}

@end



@implementation WCMessageConversation : WCConversation

+ (id)rootConversation {
	return [[[self alloc] _initWithName:NSLS(@"Conversations", @"Messages item") userID:0 expandable:YES connection:NULL] autorelease];
}

@end



@implementation WCBroadcastConversation : WCConversation

+ (id)rootConversation {
	return [[[self alloc] _initWithName:NSLS(@"Broadcasts", @"Messages item") userID:0 expandable:YES connection:NULL] autorelease];
}

@end
