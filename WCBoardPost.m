/* $Id$ */

/*
 *  Copyright (c) 2008 Axel Andersson
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

#import "WCBoardPost.h"

@implementation WCBoardPost

+ (id)postWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
	return [[[self alloc] initWithMessage:message connection:connection] autorelease];
}



- (id)initWithMessage:(WIP7Message *) message connection:(WCServerConnection *)connection {
	self = [self initWithConnection:connection];
	
	_board		= [[message stringForName:@"wired.board.board"] retain];
	_thread		= [[message UUIDForName:@"wired.board.thread"] retain];
	_post		= [[message UUIDForName:@"wired.board.post"] retain];
	_postDate	= [[message dateForName:@"wired.board.post_date"] retain];
	_editDate	= [[message dateForName:@"wired.board.edit_date"] retain];
	_nick		= [[message stringForName:@"wired.board.nick"] retain];
	_subject	= [[message stringForName:@"wired.board.subject"] retain];
	_text		= [[message stringForName:@"wired.board.text"] retain];
	
	return self;
}



- (void)dealloc {
	[_board release];
	[_thread release];
	[_post release];
	[_postDate release];
	[_editDate release];
	[_nick release];
	[_subject release];
	[_text release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)board {
	return _board;
}



- (NSString *)threadID {
	return _thread;
}



- (NSString *)postID {
	return _post;
}



- (NSDate *)postDate {
	return _postDate;
}



- (NSDate *)editDate {
	return _editDate;
}



- (NSString *)nick {
	return _nick;
}



- (NSString *)subject {
	return _subject;
}



- (NSString *)text {
	return _text;
}

@end
