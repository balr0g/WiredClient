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

#import "WCBoardThread.h"

@implementation WCBoardThread

+ (id)threadWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
	return [[[self alloc] initWithMessage:message connection:connection] autorelease];
}



- (id)initWithMessage:(WIP7Message *) message connection:(WCServerConnection *)connection {
	self = [super initWithMessage:message connection:connection];
	
	_posts = [[NSMutableArray alloc] init];
	
	return self;
}



- (void)dealloc {
	[_posts release];
	
	[super dealloc];
}



#pragma mark -

- (NSUInteger)numberOfPosts {
	return [_posts count];
}



- (NSArray *)posts {
	return _posts;
}



- (WCBoardPost *)postAtIndex:(NSUInteger)index {
	return [_posts objectAtIndex:index];
}



- (void)addPost:(WCBoardPost *)post {
	[_posts addObject:post];
}



- (void)removePost:(WCBoardPost *)post {
	[_posts removeObject:post];
}



- (void)removeAllPosts {
	[_posts removeAllObjects];
}

@end
