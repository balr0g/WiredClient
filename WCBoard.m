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

#import "WCBoard.h"
#import "WCBoardThread.h"

@interface WCBoard(Private)

- (id)_initWithPath:(NSString *)path name:(NSString *)name connection:(WCServerConnection *)connection ;

- (WCBoard *)_boardWithName:(NSString *)name;

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

@end



@implementation WCBoard

+ (id)rootBoard {
	return [[[self alloc] _initWithPath:@"/" name:@"<root>" connection:NULL] autorelease];
}



+ (id)boardWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithPath:@"/" name:[connection name] connection:connection] autorelease];
}



+ (id)boardWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
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



- (NSUInteger)numberOfUnreadThreads {
	NSEnumerator		*enumerator;
	WCBoardThread		*thread;
	NSUInteger			count = 0;
	
	enumerator = [_threadsArray objectEnumerator];
	
	while((thread = [enumerator nextObject])) {
		if([thread isUnread])
			count++;
	}
	
	return count;
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



- (void)addThread:(WCBoardThread *)thread sortedUsingSelector:(SEL)selector {
	[_threadsArray addObject:thread sortedUsingSelector:selector];
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
