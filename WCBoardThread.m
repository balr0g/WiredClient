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

#import "WCBoardPost.h"
#import "WCBoardThread.h"

@implementation WCBoardThread

+ (WCBoardThread *)threadWithPost:(WCBoardPost *)post connection:(WCServerConnection *)connection {
	return [[[self alloc] initWithPost:post connection:connection] autorelease];
}



- (id)initWithPost:(WCBoardPost *)post connection:(WCServerConnection *)connection {
	self = [super initWithConnection:connection];
	
	_goToLatestPostButton	= [[NSButton alloc] init];
	
	[_goToLatestPostButton setButtonType:NSMomentaryLightButton];
	[_goToLatestPostButton setBordered:NO];
	[[_goToLatestPostButton cell] setHighlightsBy:NSContentsCellMask];
	[_goToLatestPostButton setImage:[NSImage imageNamed:@"GoToLatestPost"]];
	[_goToLatestPostButton retain];
	
	_posts					= [[NSMutableArray alloc] init];
	_threadID				= [[post threadID] retain];
	_unread					= [post isUnread];
	
	[_posts addObject:post];
	
	return self;
}



- (void)dealloc {
	[_threadID release];
	[_posts release];

	[_goToLatestPostButton removeFromSuperview];
	[_goToLatestPostButton release];
	
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



- (void)setBoard:(WCBoard *)board {
	NSEnumerator		*enumerator;
	WCBoardPost			*post;

	_board = board;

	enumerator = [_posts objectEnumerator];
	
	while((post = [enumerator nextObject]))
		[post setBoard:[board path]];
}



- (WCBoard *)board {
	return _board;
}



#pragma mark -

- (NSButton *)goToLatestPostButton {
	return _goToLatestPostButton;
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



- (WCBoardPost *)firstPost {
	return [_posts objectAtIndex:0];
}



- (WCBoardPost *)lastPost {
	return [_posts lastObject];
}



- (BOOL)hasPostMatchingFilter:(WCBoardThreadFilter *)filter {
	NSEnumerator		*enumerator;
	NSString			*boardString, *textString, *subjectString, *nickString;
	WCBoardPost			*post;
	
	if([filter unread] && ![self isUnread])
		return NO;
	
	boardString		= [filter board];
	textString		= [filter text];
	subjectString	= [filter subject];
	nickString		= [filter nick];
	enumerator		= [_posts objectEnumerator];
	
	while((post = [enumerator nextObject])) {
		if([boardString length] > 0) {
			if([[[post board] lastPathComponent] containsSubstring:boardString options:NSCaseInsensitiveSearch])
				return YES;
			else
				continue;
		}
		
		if([filter unread]) {
			if([post isUnread])
				return YES;
			else
				continue;
		}

		if([textString length] > 0 && [[post text] containsSubstring:textString options:NSCaseInsensitiveSearch])
			return YES;

		if([subjectString length] > 0 && [[post subject] containsSubstring:subjectString options:NSCaseInsensitiveSearch])
			return YES;

		if([nickString length] > 0 && [[post nick] containsSubstring:nickString options:NSCaseInsensitiveSearch])
			return YES;
	}
	
	return NO;
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
	
	result = [[[self firstPost] subject] compare:[[object firstPost] subject] options:NSCaseInsensitiveSearch];
	
	if(result == NSOrderedSame)
		result = [self compareDate:object];
	
	return result;
}



- (NSComparisonResult)compareNick:(id)object {
	NSComparisonResult		result;
	
	result = [[[self firstPost] nick] compare:[[object firstPost] nick] options:NSCaseInsensitiveSearch];
	
	if(result == NSOrderedSame)
		result = [self compareDate:object];
	
	return result;
}



- (NSComparisonResult)compareNumberOfPosts:(id)object {
	if([self numberOfPosts] > [object numberOfPosts])
		return NSOrderedAscending;
	else if([self numberOfPosts] < [object numberOfPosts])
		return NSOrderedDescending;

	return [self compareLastPostDate:object];
}



- (NSComparisonResult)compareDate:(id)object {
	return [[[self firstPost] postDate] compare:[[object firstPost] postDate]];
}



- (NSComparisonResult)compareLastPostDate:(id)object {
	return [[[self lastPost] postDate] compare:[[object lastPost] postDate]];
}

@end



@implementation WCBoardThreadFilter

+ (NSInteger)version {
	return 2;
}



#pragma mark -

+ (id)filter {
	return [[[self alloc] init] autorelease];
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	_name			= [[coder decodeObjectForKey:@"WCBoardThreadFilterName"] retain];
	_board			= [[coder decodeObjectForKey:@"WCBoardThreadFilterBoard"] retain];
	_text			= [[coder decodeObjectForKey:@"WCBoardThreadFilterText"] retain];
	_subject		= [[coder decodeObjectForKey:@"WCBoardThreadFilterSubject"] retain];
	_nick			= [[coder decodeObjectForKey:@"WCBoardThreadFilterNick"] retain];
	_unread			= [coder decodeBoolForKey:@"WCBoardThreadFilterUnread"];
	
	if(!_board)
		_board = [@"" retain];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:[[self class] version] forKey:@"WCBoardThreadFilterVersion"];
	
	[coder encodeObject:_name forKey:@"WCBoardThreadFilterName"];
	[coder encodeObject:_board forKey:@"WCBoardThreadFilterBoard"];
	[coder encodeObject:_text forKey:@"WCBoardThreadFilterText"];
	[coder encodeObject:_subject forKey:@"WCBoardThreadFilterSubject"];
	[coder encodeObject:_nick forKey:@"WCBoardThreadFilterNick"];
	[coder encodeBool:_unread forKey:@"WCBoardThreadFilterUnread"];
}



- (void)dealloc {
	[_name release];
	[_board release];
	[_text release];
	[_subject release];
	[_nick release];
	
	[super dealloc];
}



#pragma mark -

- (void)setName:(NSString *)name {
	[name retain];
	[_name release];
	
	_name = name;
}



- (NSString *)name {
	return _name;
}



- (void)setBoard:(NSString *)board {
	[board retain];
	[_board release];
	
	_board = board;
}



- (NSString *)board {
	return _board;
}



- (void)setText:(NSString *)text {
	[text retain];
	[_text release];
	
	_text = text;
}



- (NSString *)text {
	return _text;
}



- (void)setSubject:(NSString *)subject {
	[subject retain];
	[_subject release];
	
	_subject = subject;
}



- (NSString *)subject {
	return _subject;
}



- (void)setNick:(NSString *)nick {
	[nick retain];
	[_nick release];
	
	_nick = nick;
}



- (NSString *)nick {
	return _nick;
}



- (void)setUnread:(BOOL)unread {
	_unread = unread;
}



- (BOOL)unread {
	return _unread;
}

@end
