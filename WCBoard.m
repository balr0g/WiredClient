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

#import "WCAccount.h"
#import "WCBoard.h"
#import "WCBoardThread.h"

@interface WCBoard(Private)

- (id)_initWithPath:(NSString *)path name:(NSString *)name connection:(WCServerConnection *)connection ;

- (WCBoard *)_boardWithName:(NSString *)name;
- (WCBoardThread *)_unreadThreadStartingAtBoard:(WCBoard *)startingBoard thread:(WCBoardThread *)startingThread forwardsInBoards:(BOOL)forwardsInBoards forwardsInThreads:(BOOL)forwardsInThreads passed:(BOOL *)passed;

@end


@implementation WCBoard(Private)

- (id)_initWithPath:(NSString *)path name:(NSString *)name connection:(WCServerConnection *)connection {
	self = [self initWithConnection:connection];
	
	_name				= [name retain];
	_path				= [path retain];
	_boards				= [[NSMutableArray alloc] init];
	_threadsArray		= [[NSMutableArray alloc] init];
	_threadsDictionary	= [[NSMutableDictionary alloc] init];
	
	return self;
}



#pragma mark -

- (WCBoard *)_boardWithName:(NSString *)name {
	NSEnumerator	*enumerator;
	WCBoard			*board;
	
	enumerator = [_boards objectEnumerator];
	
	while((board = [enumerator nextObject])) {
		if([[board name] isEqualToString:name])
			return board;
	}
	
	return NULL;
}



#pragma mark -

- (WCBoardThread *)_unreadThreadStartingAtBoard:(WCBoard *)startingBoard thread:(WCBoardThread *)startingThread forwardsInBoards:(BOOL)forwardsInBoards forwardsInThreads:(BOOL)forwardsInThreads passed:(BOOL *)passed {
	WCBoard			*board;
	WCBoardThread	*thread;
	NSUInteger		i, count;
	
	count = [_threadsArray count];
	
	for(i = 0; i < count; i++) {
		thread = [_threadsArray objectAtIndex:forwardsInThreads ? i : count - i - 1];
		
		if((startingBoard == NULL || startingBoard == self) &&
		   (startingThread == NULL || startingThread == thread))
			*passed = YES;
		
		if(*passed && thread != startingThread && [thread isUnread])
			return thread;
	}
	
	count = [_boards count];
	
	for(i = 0; i < count; i++) {
		board = [_boards objectAtIndex:forwardsInBoards ? i : count - i - 1];
		thread = [board _unreadThreadStartingAtBoard:startingBoard
											  thread:startingThread
									forwardsInBoards:forwardsInBoards
								   forwardsInThreads:forwardsInThreads
											  passed:passed];
		
		if(thread)
			return thread;
	}
	
	return NULL;
}

@end



@implementation WCBoard

+ (WCBoard *)rootBoard {
	return [[[self alloc] _initWithPath:@"/" name:@"<root>" connection:NULL] autorelease];
}



+ (WCBoard *)boardWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithPath:@"/" name:[connection name] connection:connection] autorelease];
}



+ (WCBoard *)boardWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
	NSString		*path, *owner, *group;
	WCBoard			*board;
	NSUInteger		permissions;
	WIP7Bool		value;
	
	path	= [message stringForName:@"wired.board.board"];
	owner	= [message stringForName:@"wired.board.owner"];
	group	= [message stringForName:@"wired.board.group"];
	
	permissions = 0;
	
	if([message getBool:&value forName:@"wired.board.owner.read"] && value)
		permissions |= WCBoardOwnerRead;
	
	if([message getBool:&value forName:@"wired.board.owner.write"] && value)
		permissions |= WCBoardOwnerWrite;
	
	if([message getBool:&value forName:@"wired.board.group.read"] && value)
		permissions |= WCBoardGroupRead;
	
	if([message getBool:&value forName:@"wired.board.group.write"] && value)
		permissions |= WCBoardGroupWrite;
	
	if([message getBool:&value forName:@"wired.board.everyone.read"] && value)
		permissions |= WCBoardEveryoneRead;
	
	if([message getBool:&value forName:@"wired.board.everyone.write"] && value)
		permissions |= WCBoardEveryoneWrite;
	
	board = [[self alloc] _initWithPath:path name:[path lastPathComponent] connection:connection];
	[board setOwner:owner];
	[board setGroup:group];
	[board setPermissions:permissions];
	
	return [board autorelease];
}



- (void)dealloc {
	[_name release];
	[_path release];
	[_boards release];
	[_threadsArray release];
	[_threadsDictionary release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)description {
	return [NSSWF:@"<%@: %p>{board = %@}", [self class], self, [self path]];
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



- (void)setPath:(NSString *)path {
	[path retain];
	[_path release];
	
	_path = path;
}



- (NSString *)path {
	return _path;
}



- (void)setOwner:(NSString *)owner {
	[owner retain];
	[_owner release];
	
	_owner = owner;
}



- (NSString *)owner {
	return _owner;
}



- (void)setGroup:(NSString *)group {
	[group retain];
	[_group release];
	
	_group = group;
}



- (NSString *)group {
	return _group;
}



- (void)setPermissions:(NSUInteger)permissions {
	_permissions = permissions;
}



- (NSUInteger)permissions {
	return _permissions;
}



- (BOOL)isExpandable {
	return ([_boards count] > 0);
}



- (BOOL)isModifiable {
	return ![_path isEqualToString:@"/"];
}



- (BOOL)isWritableByAccount:(WCUserAccount *)account {
	if(_permissions & WCBoardEveryoneWrite)
		return YES;
	
	if(_permissions & WCBoardGroupWrite) {
		if([[account group] isEqualToString:_group] || [[account groups] containsObject:_group])
			return YES;
	}
	
	if(_permissions & WCBoardOwnerWrite) {
		if([[account name] isEqualToString:_owner])
			return YES;
	}
	
	return NO;
}



#pragma mark -

- (NSUInteger)numberOfBoards {
	return [_boards count];
}



- (NSArray *)boards {
	return _boards;
}



- (WCBoard *)boardAtIndex:(NSUInteger)index {
	return [_boards objectAtIndex:index];
}



- (WCBoard *)boardForConnection:(WCServerConnection *)connection {
	NSEnumerator	*enumerator;
	WCBoard			*board;
	
	enumerator = [_boards objectEnumerator];
	
	while((board = [enumerator nextObject])) {
		if([board connection] == connection)
			return board;
	}
	
	return NULL;
}



- (WCBoard *)boardForPath:(NSString *)path {
	NSEnumerator	*enumerator;
	NSArray			*components;
	NSString		*component;
	WCBoard			*board, *child;
	
	components	= [path componentsSeparatedByString:@"/"];

	if([components count] == 0)
		return self;
	
	board = self;
	enumerator = [components objectEnumerator];
	
	while((component = [enumerator nextObject])) {
		child = [board _boardWithName:component];
		
		if(!child)
			break;
		
		board = child;
	}
	
	return board;
}



- (void)addBoard:(WCBoard *)board {
	[_boards addObject:board sortedUsingSelector:@selector(compareName:)];
}



- (void)removeBoard:(WCBoard *)board {
	[_boards removeObject:board];
}



- (void)removeAllBoards {
	[_boards removeAllObjects];
}



#pragma mark -

- (NSUInteger)numberOfThreads {
	return [_threadsArray count];
}



- (NSUInteger)numberOfUnreadThreadsForConnection:(WCServerConnection *)connection includeChildBoards:(BOOL)includeChildBoards {
	WCBoard				*board;
	WCBoardThread		*thread;
	NSUInteger			i, count, unread = 0;
	
	count = [_threadsArray count];
	
	for(i = 0; i < count; i++) {
		thread = [_threadsArray objectAtIndex:i];

		if(!connection || [thread connection] == connection) {
			if([thread isUnread])
				unread++;
		}
	}
	
	if(includeChildBoards) {
		count = [_boards count];
		
		for(i = 0; i < count; i++) {
			board = [_boards objectAtIndex:i];
			
			if(![board isKindOfClass:[WCSmartBoard class]])
				unread += [board numberOfUnreadThreadsForConnection:connection includeChildBoards:includeChildBoards];
		}
	}
	
	return unread;
}



- (NSArray *)threads {
	return _threadsArray;
}



- (WCBoardThread *)threadAtIndex:(NSUInteger)index {
	return [_threadsArray objectAtIndex:index];
}



- (WCBoardThread *)threadWithID:(NSString *)string {
	return [_threadsDictionary objectForKey:string];
}



- (NSUInteger)indexOfThread:(WCBoardThread *)thread {
	return [_threadsArray indexOfObject:thread];
}



- (NSArray *)threadsMatchingFilter:(WCBoardThreadFilter *)filter includeChildBoards:(BOOL)includeChildBoards {
	NSMutableArray		*threads;
	WCBoard				*board;
	WCBoardThread		*thread;
	NSUInteger			i, count;
	
	threads		= [NSMutableArray array];
	count		= [_threadsArray count];
	
	for(i = 0; i < count; i++) {
		thread = [_threadsArray objectAtIndex:i];
		
		if([thread hasPostMatchingFilter:filter])
			[threads addObject:thread];
	}
	
	if(includeChildBoards) {
		count = [_boards count];
		
		for(i = 0; i < count; i++) {
			board = [_boards objectAtIndex:i];
			
			if(![board isKindOfClass:[WCSmartBoard class]])
				[threads addObjectsFromArray:[board threadsMatchingFilter:filter includeChildBoards:includeChildBoards]];
		}
	}
	
	return threads;
}



- (WCBoardThread *)previousUnreadThreadStartingAtBoard:(WCBoard *)board thread:(WCBoardThread *)thread forwardsInThreads:(BOOL)forwardsInThreads {
	BOOL	passed = NO;
	
	return [self _unreadThreadStartingAtBoard:board thread:thread forwardsInBoards:NO forwardsInThreads:!forwardsInThreads passed:&passed];
}



- (WCBoardThread *)nextUnreadThreadStartingAtBoard:(WCBoard *)board thread:(WCBoardThread *)thread forwardsInThreads:(BOOL)forwardsInThreads {
	BOOL	passed = NO;
	
	return [self _unreadThreadStartingAtBoard:board thread:thread forwardsInBoards:YES forwardsInThreads:forwardsInThreads passed:&passed];
}



- (void)addThread:(WCBoardThread *)thread sortedUsingSelector:(SEL)selector {
	[_threadsArray addObject:thread sortedUsingSelector:selector];
	[_threadsDictionary setObject:thread forKey:[thread threadID]];
}



- (void)addThreads:(NSArray *)threads {
	NSEnumerator		*enumerator;
	WCBoardThread		*thread;
	
	[_threadsArray addObjectsFromArray:threads];
	
	enumerator = [threads objectEnumerator];
	
	while((thread = [enumerator nextObject]))
		[_threadsDictionary setObject:thread forKey:[thread threadID]];
}



- (void)removeThread:(WCBoardThread *)thread {
	[_threadsArray removeObject:thread];
	[_threadsDictionary removeObjectForKey:[thread threadID]];
}



- (void)removeAllThreads {
	[_threadsArray removeAllObjects];
	[_threadsDictionary removeAllObjects];
}



- (void)sortThreadsUsingSelector:(SEL)selector {
	[_threadsArray sortUsingSelector:selector];
}



#pragma mark -

- (void)invalidateForConnection:(WCServerConnection *)connection {
	WCBoard			*board;
	WCBoardThread	*thread;
	NSUInteger		i, count;
	
	count = [_threadsArray count];
	
	for(i = 0; i < count; i++) {
		thread = [_threadsArray objectAtIndex:i];
		
		if([thread connection] == connection) {
			[thread setConnection:NULL];
			[[thread posts] makeObjectsPerformSelector:@selector(setConnection:) withObject:NULL];
		}
	}
	
	count = [_boards count];
	
	for(i = 0; i < count; i++) {
		board = [_boards objectAtIndex:i];
		
		if([board connection] == connection)
			[board setConnection:NULL];
		
		[board invalidateForConnection:connection];
	}
}



- (void)revalidateForConnection:(WCServerConnection *)connection {
	WCBoard			*board;
	WCBoardThread	*thread;
	NSUInteger		i, count;
	
	count = [_threadsArray count];
	
	for(i = 0; i < count; i++) {
		thread = [_threadsArray objectAtIndex:i];
		
		if([thread belongsToConnection:connection]) {
			[thread setConnection:connection];
			[[thread posts] makeObjectsPerformSelector:@selector(setConnection:) withObject:connection];
		}
	}
	
	count = [_boards count];
	
	for(i = 0; i < count; i++) {
		board = [_boards objectAtIndex:i];
		
		if([board belongsToConnection:connection])
			[board setConnection:connection];
		
		[board revalidateForConnection:connection];
	}
}



#pragma mark -

- (NSComparisonResult)compareName:(WCBoard *)board {
	return [[self name] compare:[board name] options:NSCaseInsensitiveSearch];
}

@end



@implementation WCSmartBoard

+ (id)smartBoard {
	return [self rootBoard];
}



#pragma mark -

- (void)setFilter:(WCBoardThreadFilter *)filter {
	[filter retain];
	[_filter release];
	
	_filter = filter;
}



- (WCBoardThreadFilter *)filter {
	return _filter;
}

@end
