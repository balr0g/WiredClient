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

#import "WCMessage.h"
#import "WCUser.h"

@interface WCMessage(Private)

- (id)_initWithDirection:(WCMessageDirection)direction message:(NSString *)message user:(WCUser *)user read:(BOOL)read connection:(WCServerConnection *)connection;

@end


@implementation WCMessage(Private)

- (id)_initWithDirection:(WCMessageDirection)direction message:(NSString *)message user:(WCUser *)user read:(BOOL)read connection:(WCServerConnection *)connection {
	self = [super initWithConnection:connection];

	_direction		= direction;
	_userID			= [user userID];
	_userNick		= [[user nick] retain];
	_message		= [message retain];
	_date			= [[NSDate date] retain];
	_read			= read;

	return self;
}

@end


@implementation WCMessage

- (void)dealloc {
	[_userNick release];
	[_message release];
	[_date release];

	[super dealloc];
}



#pragma mark -

- (NSString *)description {
	NSString	*type = @"";
	
	if([self isKindOfClass:[WCPrivateMessage class]])
		type = @"message";
	else
		type = @"broadcast";
	
	return [NSSWF:@"<%@ %p>{type = %@, user = %@, date = %@}",
		[self className],
		self,
		type,
		[self userNick],
		[self date]];
}



#pragma mark -

- (WCMessageDirection)direction {
	return _direction;
}



- (NSUInteger)userID {
	return _userID;
}



- (NSString *)userNick {
	return _userNick;
}



- (NSString *)message {
	return _message;
}



- (NSDate *)date {
	return _date;
}



#pragma mark -

- (void)setRead:(BOOL)read {
	_read = read;
}



- (BOOL)isRead {
	return _read;
}



- (void)setConversation:(WCConversation *)conversation {
	_conversation = conversation;
}



- (WCConversation *)conversation {
	return _conversation;
}



#pragma mark -

- (NSComparisonResult)compareUser:(WCMessage *)message {
	NSComparisonResult	result;
	
	result = [[self userNick] compare:[message userNick] options:NSCaseInsensitiveSearch];
	
	if(result != NSOrderedSame)
		return result;
	
	return [self compareDate:message];
}



- (NSComparisonResult)compareDate:(WCMessage *)message {
	return [[self date] compare:[message date]];
}

@end



@implementation WCPrivateMessage

+ (id)messageWithMessage:(NSString *)message user:(WCUser *)user connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithDirection:WCMessageFrom message:message user:user read:NO connection:connection] autorelease];
}



+ (id)messageToUser:(WCUser *)user message:(NSString *)message connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithDirection:WCMessageTo message:message user:user read:YES connection:connection] autorelease];
}

@end



@implementation WCBroadcastMessage

+ (id)broadcastWithMessage:(NSString *)message user:(WCUser *)user connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithDirection:WCMessageFrom message:message user:user read:NO connection:connection] autorelease];
}

@end
