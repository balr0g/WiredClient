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

- (id)_initWithName:(NSString *)name expandable:(BOOL)expandable connection:(WCServerConnection *)connection;

- (id)_unreadMessageStartingAtConversation:(id)startingConversation message:(id)startingMessage forwardsInConversations:(BOOL)forwardsInConversations forwardsInMessages:(BOOL)forwardsInMessages passed:(BOOL)passed;

@end


@implementation WCConversation(Private)

- (id)_initWithName:(NSString *)name expandable:(BOOL)expandable connection:(WCServerConnection *)connection {
	self = [self initWithConnection:connection];
	
	_name			= [name retain];
	_expandable		= expandable;
	
	return self;
}



#pragma mark -

- (id)_unreadMessageStartingAtConversation:(id)startingConversation message:(id)startingMessage forwardsInConversations:(BOOL)forwardsInConversations forwardsInMessages:(BOOL)forwardsInMessages passed:(BOOL)passed {
	WCConversation	*conversation;
	WCMessage		*message;
	NSUInteger		i, count;
	
	count = [_messages count];
	
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:forwardsInMessages ? i : count - i - 1];
		
		if((startingConversation == NULL || startingConversation == self) &&
		   (startingMessage == NULL || startingMessage == message))
			passed = YES;
		
		if(passed && ![message isRead])
			return message;
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++) {
		conversation = [_conversations objectAtIndex:forwardsInConversations ? i : count - i - 1];
		message = [conversation _unreadMessageStartingAtConversation:startingConversation
															 message:startingMessage
											 forwardsInConversations:forwardsInConversations
												  forwardsInMessages:forwardsInMessages
															  passed:passed];
		
		if(message)
			return message;
	}
	
	return NULL;
}

@end



@implementation WCConversation

+ (NSInteger)version {
	return 1;
}



#pragma mark -

+ (id)rootConversation {
	return [[[self alloc] _initWithName:@"<root>" expandable:YES connection:NULL] autorelease];
}



+ (id)conversationWithUser:(WCUser *)user connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithName:[user nick] expandable:NO connection:connection] autorelease];
}



- (id)initWithConnection:(WCServerConnection *)connection {
	self = [super initWithConnection:connection];
	
	_conversations	= [[NSMutableArray alloc] init];
	_messages		= [[NSMutableArray alloc] init];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
	
	if(!self)
		return NULL;
	
    if([coder decodeIntForKey:@"WCConversationVersion"] != [[self class] version]) {
        [self release];
		
        return NULL;
    }
	
	_name			= [[coder decodeObjectForKey:@"WCConversationName"] retain];
	_conversations	= [[coder decodeObjectForKey:@"WCConversationConversations"] retain];
	_messages		= [[coder decodeObjectForKey:@"WCConversationMessages"] retain];
	_expandable		= [coder decodeBoolForKey:@"WCConversationExpandable"];

	[_messages makeObjectsPerformSelector:@selector(setConversation:) withObject:self];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:[[self class] version] forKey:@"WCConversationVersion"];
	
	[coder encodeObject:_name forKey:@"WCConversationName"];
	[coder encodeObject:_conversations forKey:@"WCConversationConversations"];
	[coder encodeObject:_messages forKey:@"WCConversationMessages"];
	[coder encodeBool:_expandable forKey:@"WCConversationExpandable"];
	
	[super encodeWithCoder:coder];
}



- (void)dealloc {
	[_name release];
	[_conversations release];
	[_messages release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)name {
	return _name;
}



- (BOOL)isExpandable {
	return _expandable;
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

		if((WCUser *) [[[conversation messages] lastObject] user] == user && [conversation connection] == connection)
			return conversation;
	}
	
	return NULL;
}



- (void)addConversations:(NSArray *)conversations {
	[_conversations addObjectsFromArray:conversations];
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



- (id)previousUnreadMessageStartingAtConversation:(id)conversation message:(id)message forwardsInMessages:(BOOL)forwardsInMessages {
	return [self _unreadMessageStartingAtConversation:conversation message:message forwardsInConversations:NO forwardsInMessages:!forwardsInMessages passed:NO];
}



- (id)nextUnreadMessageStartingAtConversation:(id)conversation message:(id)message forwardsInMessages:(BOOL)forwardsInMessages {
	return [self _unreadMessageStartingAtConversation:conversation message:message forwardsInConversations:YES forwardsInMessages:forwardsInMessages passed:NO];
}



- (void)sortMessagesUsingSelector:(SEL)selector {
	[_messages sortUsingSelector:selector];
}



- (void)addMessage:(id)message {
	[message setConversation:self];
	[_messages addObject:message];
}



- (void)removeMessage:(id)message {
	[message setConversation:NULL];
	[_messages removeObject:message];
}



- (void)removeAllMessages {
	[_messages makeObjectsPerformSelector:@selector(setConversation:) withObject:NULL];
	[_messages removeAllObjects];
}



#pragma mark -

- (void)invalidateForConnection:(WCServerConnection *)connection {
	WCConversation	*conversation;
	WCMessage		*message;
	NSUInteger		i, count;
	
	count = [_messages count];
		
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:i];
		
		if([message connection] == connection) {
			[message setConnection:NULL];
			[message setUser:NULL];
		}
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++) {
		conversation = [_conversations objectAtIndex:i];
		
		if([conversation connection] == connection)
			[conversation setConnection:NULL];
		
		[conversation invalidateForConnection:connection];
	}
}



- (void)revalidateForConnection:(WCServerConnection *)connection {
	WCConversation	*conversation;
	WCMessage		*message;
	NSUInteger		i, count;
	
	count = [_messages count];
		
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:i];
		
		if([message belongsToConnection:connection])
			[message setConnection:connection];
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++) {
		conversation = [_conversations objectAtIndex:i];
		
		if([conversation belongsToConnection:connection])
			[conversation setConnection:connection];
		
		[conversation revalidateForConnection:connection];
	}
}



- (void)invalidateForConnection:(WCServerConnection *)connection user:(WCUser *)user {
	WCMessage		*message;
	NSUInteger		i, count;
	
	count = [_messages count];
	
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:i];
		
		if([message connection] == connection && [message user] == user)
			[message setUser:NULL];
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++)
		[[_conversations objectAtIndex:i] revalidateForConnection:connection user:user];
}



- (void)revalidateForConnection:(WCServerConnection *)connection user:(WCUser *)user {
	WCMessage		*message;
	NSUInteger		i, count;
	
	count = [_messages count];
	
	for(i = 0; i < count; i++) {
		message = [_messages objectAtIndex:i];
		
		if([message connection] == connection && ![message user]) {
			if([[user nick] isEqualToString:[message nick]] && [[user login] isEqualToString:[message login]]) {
				NSLog(@"reset user");
				[message setUser:user];
			}
		}
	}
	
	count = [_conversations count];
	
	for(i = 0; i < count; i++)
		[[_conversations objectAtIndex:i] revalidateForConnection:connection user:user];
}

@end



@implementation WCMessageConversation : WCConversation

+ (id)rootConversation {
	return [[[self alloc] _initWithName:NSLS(@"Conversations", @"Messages item") expandable:YES connection:NULL] autorelease];
}

@end



@implementation WCBroadcastConversation : WCConversation

+ (id)rootConversation {
	return [[[self alloc] _initWithName:NSLS(@"Broadcasts", @"Messages item") expandable:YES connection:NULL] autorelease];
}

@end
