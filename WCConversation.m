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
#import "WCUser.h"

@interface WCConversation(Private)

- (id)_initWithMessage:(WCMessage *)message;

@end


@implementation WCConversation(Private)

- (id)_initWithMessage:(WCMessage *)message {
	self = [super initWithConnection:[message connection]];
	
	_messages = [[NSMutableArray alloc] initWithObjects:message, NULL];
	
	return self;
}

@end



@implementation WCConversation

+ (id)conversationWithMessage:(WCMessage *)message {
	return [[[self alloc] _initWithMessage:message] autorelease];
}



- (void)dealloc {
	[_messages release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)description {
	NSString	*type = @"";
	
	if([self messageClass] == [WCPrivateMessage class])
		type = @"message";
	else
		type = @"broadcast";
	
	return [NSSWF:@"<%@ %p>{type = %@, user = %@}",
		[self className],
		self,
		type,
		[self userNick]];
}



#pragma mark -

- (void)addMessage:(WCMessage *)message {
	[_messages addObject:message];
}



- (NSArray *)messages {
	return _messages;
}



- (Class)messageClass {
	return [[_messages lastObject] class];
}



- (NSUInteger)userID {
	return [[_messages lastObject] userID];
}



- (NSString *)userNick {
	return [[_messages lastObject] userNick];
}

@end
