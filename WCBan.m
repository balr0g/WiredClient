/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "WCBan.h"

@interface WCBan(Private)

- (id)_initWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection;

@end


@implementation WCBan(Private)

- (id)_initWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
	self = [self initWithConnection:connection];
	
	_ip					= [[message stringForName:@"wired.banlist.ip"] retain];
	_expirationDate		= [[message dateForName:@"wired.banlist.expiration_date"] retain];
	
	return self;
}

@end



@implementation WCBan

+ (id)banWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithMessage:message connection:connection] autorelease];
}



- (void)dealloc {
	[_ip release];
	[_expirationDate release];

	[super dealloc];
}



#pragma mark -

- (NSString *)IP {
	return _ip;
}



- (NSDate *)expirationDate {
	return _expirationDate;
}



#pragma mark -

- (NSComparisonResult)compareIP:(WCBan *)ban {
	return [[self IP] compare:[ban IP] options:NSCaseInsensitiveSearch];
}



- (NSComparisonResult)compareExpirationDate:(WCBan *)ban {
	NSComparisonResult		result;
	
	if(![self expirationDate] && [ban expirationDate])
		return NSOrderedAscending;
	else if([self expirationDate] && ![ban expirationDate])
		return NSOrderedDescending;
	
	result = [[self expirationDate] compare:[ban expirationDate]];
	
	if(result == NSOrderedSame)
		result = [self compareIP:ban];
	
	return result;
}

@end
