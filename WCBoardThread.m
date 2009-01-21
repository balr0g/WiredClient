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
#import "WCBoardThread.h"

@implementation WCBoardThread

+ (id)threadWithPost:(WCBoardPost *)post connection:(WCServerConnection *)connection {
	return [[[self alloc] initWithPost:post connection:connection] autorelease];
}



- (id)initWithPost:(WCBoardPost *)post connection:(WCServerConnection *)connection {
	self = [super initWithConnection:connection];
	
	_posts		= [[NSMutableArray alloc] init];
	_threadID	= [[post threadID] retain];
	_unread		= [post isUnread];
	
	[_posts addObject:post];
	
	return self;
}



- (void)dealloc {
	[_threadID release];
	[_posts release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)description {
	return [NSSWF:@"<%@: %p>{id = %@, posts = %@}", [self class], self, [self threadID], [self posts]];
}



#pragma mark -

- (NSString *)threadID {
	return _threadID;
}



- (void)setUnread:(BOOL)unread {
	_unread = unread;
}



- (BOOL)isUnread {
	return _unread;
}



#pragma mark -

- (NSUInteger)numberOfPosts {
	return [_posts count];
}



- (NSUInteger)numberOfUnreadPosts {
	NSEnumerator		*enumerator;
	WCBoardPost			*post;
	NSUInteger			count = 0;
	
	enumerator = [_posts objectEnumerator];
	
	while((post = [enumerator nextObject])) {
		if([post isUnread])
			count++;
	}
	
	return count;
}



- (NSArray *)posts {
	return _posts;
}



- (WCBoardPost *)postAtIndex:(NSUInteger)index {
	return [_posts objectAtIndex:index];
}



- (WCBoardPost *)postWithID:(NSString *)postID {
	NSEnumerator		*enumerator;
	WCBoardPost			*post;
	
	enumerator = [_posts objectEnumerator];
	
	while((post = [enumerator nextObject])) {
		if([[post postID] isEqualToString:postID])
			return post;
	}
	
	return NULL;
}



- (void)addPost:(WCBoardPost *)post {
	[_posts addObject:post sortedUsingSelector:@selector(compareDate:)];
}



- (void)removePost:(WCBoardPost *)post {
	[_posts removeObject:post];
}



- (void)removeAllPosts {
	[_posts removeAllObjects];
}



#pragma mark -

- (NSComparisonResult)compareUnread:(id)object {
	if([self isUnread] && ![object isUnread])
		return NSOrderedAscending;
    else if(![self isUnread] && [object isUnread])
        return NSOrderedDescending;
	
	return [self compareDate:object];
}



- (NSComparisonResult)compareSubject:(id)object {
	NSComparisonResult		result;
	
	result = [[[_posts objectAtIndex:0] subject] compare:[[object postAtIndex:0] subject] options:NSCaseInsensitiveSearch];
	
	if(result == NSOrderedSame)
		result = [self compareDate:object];
	
	return result;
}



- (NSComparisonResult)compareNick:(id)object {
	NSComparisonResult		result;
	
	result = [[[_posts objectAtIndex:0] nick] compare:[[object postAtIndex:0] nick] options:NSCaseInsensitiveSearch];
	
	if(result == NSOrderedSame)
		result = [self compareDate:object];
	
	return result;
}



- (NSComparisonResult)compareDate:(id)object {
	return [[[_posts objectAtIndex:0] postDate] compare:[[object postAtIndex:0] postDate]];
}

@end
