/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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
#import "WCFile.h"
#import "WCServer.h"
#import "WCServerConnection.h"
#import "WCTransfer.h"

@interface WCTransfer(Private)

- (id)_initWithConnection:(WCServerConnection *)connection;
- (id)_initWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection;

@end


@implementation WCTransfer(Private)

- (id)_initWithConnection:(WCServerConnection *)connection {
	self = [self initWithConnection:connection];

	[self setState:WCTransferWaiting];

	_untransferredFilesList		= [[NSMutableArray alloc] init];
	_transferredFilesList		= [[NSMutableArray alloc] init];
	_untransferredFilesSet		= [[NSMutableSet alloc] init];
	_transferredFilesSet		= [[NSMutableSet alloc] init];

	_uncreatedDirectoriesList	= [[NSMutableArray alloc] init];
	_createdDirectoriesList		= [[NSMutableArray alloc] init];
	_uncreatedDirectoriesSet	= [[NSMutableSet alloc] init];
	_createdDirectoriesSet		= [[NSMutableSet alloc] init];
	
	[self refreshSpeedLimit];
	
	return self;
}



- (id)_initWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
	WIP7UInt64		dataSize, rsrcSize, transferred;
	WIP7UInt32		queuePosition, speed;
	
	self = [self initWithConnection:connection];
	
	_remotePath		= [[message stringForName:@"wired.file.path"] retain];
	
	[message getUInt64:&dataSize forName:@"wired.transfer.data_size"];
	[message getUInt64:&rsrcSize forName:@"wired.transfer.rsrc_size"];
	[message getUInt64:&transferred forName:@"wired.transfer.transferred"];
	[message getUInt32:&queuePosition forName:@"wired.transfer.queue_position"];
	[message getUInt32:&speed forName:@"wired.transfer.speed"];
	
	_size				= dataSize + rsrcSize;
	_dataTransferred	= transferred;
	_speed				= speed;
	_queuePosition		= queuePosition;
	
	if(_queuePosition == 0)
		_state			= WCTransferRunning;
	else
		_state			= WCTransferQueued;
	
	if(_state == WCTransferRunning) {
		[_progressIndicator setIndeterminate:NO];
		[_progressIndicator setDoubleValue:(double) _dataTransferred / (double) _size];
	}

	return self;
}

@end


@implementation WCTransfer

+ (NSInteger)version {
	return 1;
}



#pragma mark -

+ (id)transferWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithConnection:connection] autorelease];
}



+ (id)transferWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
	Class			class;
	WIP7Enum		type;
	
	if(![message getEnum:&type forName:@"wired.transfer.type"])
		return NULL;
	
	if(type == 0)
		class = [WCDownloadTransfer class];
	else
		class = [WCUploadTransfer class];
	
	return [[[class alloc] _initWithMessage:message connection:connection] autorelease];
}



#pragma mark -

- (id)init {
	self = [super init];
	
	_progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)];
	[_progressIndicator setUsesThreadedAnimation:YES];
	[_progressIndicator setMinValue:0.0];
	[_progressIndicator setMaxValue:1.0];
	
	_terminationLock = [[NSConditionLock alloc] initWithCondition:0];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
	
	if(!self)
		return NULL;
	
	if([self class] == [WCPreviewTransfer class]) {
		[self release];
		
		return NULL;
	}
	
    if([coder decodeIntForKey:@"WCTransferVersion"] != [[self class] version]) {
        [self release];
		
        return NULL;
    }
	
	_state						= [coder decodeIntForKey:@"WCTransferState"];
	_folder						= [coder decodeBoolForKey:@"WCTransferFolder"];
	_name						= [[coder decodeObjectForKey:@"WCTransferName"] retain];
	_localPath					= [[coder decodeObjectForKey:@"WCTransferLocalPath"] retain];
	_remotePath					= [[coder decodeObjectForKey:@"WCTransferRemotePath"] retain];
	_destinationPath			= [[coder decodeObjectForKey:@"WCTransferDestinationPath"] retain];
	_file						= [[coder decodeObjectForKey:@"WCTransferFile"] retain];
	_untransferredFilesList		= [[coder decodeObjectForKey:@"WCTransferUntransferredFilesList"] retain];
	_transferredFilesList		= [[coder decodeObjectForKey:@"WCTransferTransferredFilesList"] retain];
	_untransferredFilesSet		= [[coder decodeObjectForKey:@"WCTransferUntransferredFilesSet"] retain];
	_transferredFilesSet		= [[coder decodeObjectForKey:@"WCTransferTransferredFilesSet"] retain];
	_uncreatedDirectoriesList	= [[coder decodeObjectForKey:@"WCTransferUncreatedDirectoriesList"] retain];
	_createdDirectoriesList		= [[coder decodeObjectForKey:@"WCTransferCreatedDirectoriesList"] retain];
	_uncreatedDirectoriesSet	= [[coder decodeObjectForKey:@"WCTransferUncreatedDirectoriesSet"] retain];
	_createdDirectoriesSet		= [[coder decodeObjectForKey:@"WCTransferCreatedDirectoriesSet"] retain];
	_dataTransferred			= [coder decodeInt64ForKey:@"WCTransferDataTransferred"];
	_rsrcTransferred			= [coder decodeInt64ForKey:@"WCTransferRsrcTransferred"];
	_actualTransferred			= [coder decodeInt64ForKey:@"WCTransferActualTransferred"];
	_size						= [coder decodeInt64ForKey:@"WCTransferSize"];
	_accumulatedTime			= [coder decodeDoubleForKey:@"WCTransferAccumulatedTime"];
	
	if(_dataTransferred > 0 || _rsrcTransferred > 0) {
		[_progressIndicator setIndeterminate:NO];
		[_progressIndicator setDoubleValue:(double) (_dataTransferred + _rsrcTransferred)  / (double) _size];
	} else {
		[_progressIndicator setIndeterminate:YES];
	}
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:[[self class] version] forKey:@"WCTransferVersion"];
	
	[coder encodeInt:_state forKey:@"WCTransferState"];
	[coder encodeBool:_folder forKey:@"WCTransferFolder"];
	[coder encodeObject:_name forKey:@"WCTransferName"];
	[coder encodeObject:_localPath forKey:@"WCTransferLocalPath"];
	[coder encodeObject:_remotePath forKey:@"WCTransferRemotePath"];
	[coder encodeObject:_destinationPath forKey:@"WCTransferDestinationPath"];
	[coder encodeObject:_file forKey:@"WCTransferFile"];
	[coder encodeObject:_untransferredFilesList forKey:@"WCTransferUntransferredFilesList"];
	[coder encodeObject:_transferredFilesList forKey:@"WCTransferTransferredFilesList"];
	[coder encodeObject:_untransferredFilesSet forKey:@"WCTransferUntransferredFilesSet"];
	[coder encodeObject:_transferredFilesSet forKey:@"WCTransferTransferredFilesSet"];
	[coder encodeObject:_uncreatedDirectoriesList forKey:@"WCTransferUncreatedDirectoriesList"];
	[coder encodeObject:_createdDirectoriesList forKey:@"WCTransferCreatedDirectoriesList"];
	[coder encodeObject:_uncreatedDirectoriesSet forKey:@"WCTransferUncreatedDirectoriesSet"];
	[coder encodeObject:_createdDirectoriesSet forKey:@"WCTransferCreatedDirectoriesSet"];
	[coder encodeInt64:_dataTransferred forKey:@"WCTransferDataTransferred"];
	[coder encodeInt64:_rsrcTransferred forKey:@"WCTransferRsrcTransferred"];
	[coder encodeInt64:_actualTransferred forKey:@"WCTransferActualTransferred"];
	[coder encodeInt64:_size forKey:@"WCTransferSize"];
	[coder encodeDouble:_accumulatedTime forKey:@"WCTransferAccumulatedTime"];

	[super encodeWithCoder:coder];
}



- (void)dealloc {
	[_transferConnection release];
	[_name release];
	[_localPath release];
	[_remotePath release];
	[_destinationPath release];
	[_startDate release];
	[_file release];
	[_icon release];
	
	[_progressIndicator removeFromSuperview];
	[_progressIndicator release];

	[_untransferredFilesList release];
	[_transferredFilesList release];
	[_untransferredFilesSet release];
	[_transferredFilesSet release];

	[_uncreatedDirectoriesList release];
	[_createdDirectoriesList release];
	[_uncreatedDirectoriesSet release];
	[_createdDirectoriesSet release];
	
	[_terminationLock release];

	[super dealloc];
}



#pragma mark -

- (void)setState:(WCTransferState)state {
	_state = state;
	
	if(_state < WCTransferRunning && [_progressIndicator doubleValue] == 0.0)
		[_progressIndicator setIndeterminate:YES];
	else
		[_progressIndicator setIndeterminate:NO];

	if(_state == WCTransferRunning) {
		if(!_startDate)
			_startDate = [[NSDate date] retain];
	}
	else if(_startDate) {
		_accumulatedTime += [[NSDate date] timeIntervalSinceDate:_startDate];

		[_startDate release];
		_startDate = NULL;
	}
}



- (WCTransferState)state {
	return _state;
}



- (void)setQueuePosition:(NSUInteger)queuePosition {
	_queuePosition = queuePosition;
}



- (NSUInteger)queuePosition {
	return _queuePosition;
}



- (void)setTransaction:(NSUInteger)transaction {
	_transaction = transaction;
}



- (NSUInteger)transaction {
	return _transaction;
}



- (void)setSpeed:(double)speed {
	_speed = speed;
}



- (double)speed {
	return _speed;
}



- (void)setSize:(WIFileOffset)size {
	_size = size;
}



- (WIFileOffset)size {
	return _size;
}



- (void)setDataTransferred:(WIFileOffset)transferred {
	_dataTransferred = transferred;
}



- (WIFileOffset)dataTransferred {
	return _dataTransferred;
}



- (void)setRsrcTransferred:(WIFileOffset)transferred {
	_rsrcTransferred = transferred;
}



- (WIFileOffset)rsrcTransferred {
	return _rsrcTransferred;
}



- (void)setActualTransferred:(WIFileOffset)actualTransferred {
	_actualTransferred = actualTransferred;
}



- (WIFileOffset)actualTransferred {
	return _actualTransferred;
}



#pragma mark -

- (void)setFolder:(BOOL)folder {
	_folder = folder;
}



- (BOOL)isFolder {
	return _folder;
}



- (void)setPreview:(BOOL)preview {
	_preview = preview;
}



- (BOOL)isPreview {
	return _preview;
}



- (void)setSecure:(BOOL)secure {
	_secure = secure;
}



- (BOOL)isSecure {
	return _secure;
}



#pragma mark -

- (void)setTransferConnection:(WCTransferConnection *)transferConnection {
	[transferConnection retain];
	[_transferConnection release];

	_transferConnection = transferConnection;
}



- (WCTransferConnection *)transferConnection {
	return _transferConnection;
}



- (void)setName:(NSString *)name {
	[name retain];
	[_name release];

	_name = name;
}



- (NSString *)name {
	return _name;
}



- (void)setLocalPath:(NSString *)path {
	[path retain];
	[_localPath release];

	_localPath = path;
}



- (NSString *)localPath {
	return _localPath;
}



- (void)setRemotePath:(NSString *)path {
	[path retain];
	[_remotePath release];

	_remotePath = path;
}



- (NSString *)remotePath {
	return _remotePath;
}



- (void)setDestinationPath:(NSString *)path {
	[path retain];
	[_destinationPath release];

	_destinationPath = path;
}



- (NSString *)destinationPath {
	return _destinationPath;
}



- (void)setFile:(WCFile *)file {
	[file retain];
	[_file release];

	_file = file;
}



- (WCFile *)file {
	return _file;
}



- (void)setProgressIndicator:(NSProgressIndicator *)progressIndicator {
	[progressIndicator retain];
	[_progressIndicator release];

	_progressIndicator = progressIndicator;
}



- (NSProgressIndicator *)progressIndicator {
	return _progressIndicator;
}



#pragma mark -

- (BOOL)isWorking {
	return (_state == WCTransferWaiting || _state == WCTransferQueued ||
			_state == WCTransferListing || _state == WCTransferCreatingDirectories ||
			_state == WCTransferRunning);
}



- (BOOL)isTerminating {
	return (_state == WCTransferPausing || _state == WCTransferStopping ||
			_state == WCTransferDisconnecting || _state == WCTransferRemoving);
}



- (void)signalTerminated {
	[_terminationLock lock];
	[_terminationLock unlockWithCondition:1];
}



- (BOOL)waitUntilTerminatedBeforeDate:(NSDate *)date {
	if([_terminationLock lockWhenCondition:1 beforeDate:date]) {
		[_terminationLock unlock];
		
		return YES;
	}
	
	return NO;
}



- (NSString *)status {
	NSString			*format, *speed;
	NSTimeInterval		interval;
	WIFileOffset		transferred, remaining;
	WCTransferState		state;
	
	state = [self state];
	
	if(state == WCTransferWaiting && [self numberOfTransferredFiles] > 1)
		state = WCTransferRunning;
	
	switch(state) {
		case WCTransferLocallyQueued:
			return NSLS(@"Queued", @"Transfer locally queued");
			break;
			
		case WCTransferWaiting:
			return NSLS(@"Waiting", @"Transfer waiting");
			break;
			
		case WCTransferQueued:
			return [NSSWF:NSLS(@"Queued at position %lu", @"Transfer queued (position)"),
				[self queuePosition]];
			break;
		
		case WCTransferListing:
			return [NSSWF:NSLS(@"Listing directory... %lu %@", @"Transfer listing (files, 'file(s)'"),
				[self numberOfUntransferredFiles] + [self numberOfTransferredFiles],
				[self numberOfUntransferredFiles] + [self numberOfTransferredFiles] == 1
					? NSLS(@"file", @"File singular")
					: NSLS(@"files", @"File plural")];
			break;
			
		case WCTransferCreatingDirectories:
			return [NSSWF:NSLS(@"Creating directories... %lu", @"Transfer directories (directories"),
				[[self createdDirectories] count]];
			break;
			
		case WCTransferRunning:
			transferred		= [self dataTransferred] + [self rsrcTransferred];
			remaining		= (transferred < [self size]) ? [self size] - transferred : 0;
			interval		= ([self speed] > 0) ? (double) remaining / (double) [self speed] : 0;
			speed			= [NSSWF:@"%@/s", [NSString humanReadableStringForSizeInBytes:[self speed]]];
			
			if(_speedLimit > 0) {
				speed = [speed stringByAppendingFormat:@" (%@/s limit)",
					[NSString humanReadableStringForSizeInBytes:_speedLimit]];
			}
			
			if([self isFolder] && [self numberOfUntransferredFiles] + [self numberOfTransferredFiles] > 1) {
				return [NSSWF:NSLS(@"%lu of %lu files, %@ of %@, %@, %@", @"Transfer status (files, transferred, size, speed, time)"),
					[self numberOfTransferredFiles],
					[self numberOfUntransferredFiles] + [self numberOfTransferredFiles],
					[NSString humanReadableStringForSizeInBytes:transferred],
					[NSString humanReadableStringForSizeInBytes:[self size]],
					speed,
					[NSString humanReadableStringForTimeInterval:interval]];
			} else {
				return [NSSWF:NSLS(@"%@ of %@, %@, %@", @"Transfer status (transferred, size, speed, time)"),
					[NSString humanReadableStringForSizeInBytes:transferred],
					[NSString humanReadableStringForSizeInBytes:[self size]],
					speed,
					[NSString humanReadableStringForTimeInterval:interval]];
			}
			break;
			
		case WCTransferPausing:
			return [NSSWF:@"%@%C", NSLS(@"Pausing", @"Transfer pausing"), 0x2026];
			break;
			
		case WCTransferStopping:
			return [NSSWF:@"%@%C", NSLS(@"Stopping", @"Transfer stopping"), 0x2026];
			break;
			
		case WCTransferDisconnecting:
			return [NSSWF:@"%@%C", NSLS(@"Disconnecting", @"Transfer disconnecting"), 0x2026];
			break;

		case WCTransferRemoving:
			return [NSSWF:@"%@%C", NSLS(@"Removing", @"Transfer removing"), 0x2026];
			break;

		case WCTransferPaused:
		case WCTransferStopped:
		case WCTransferDisconnected:
			transferred = [self dataTransferred] + [self rsrcTransferred];
			
			if([self isFolder] && [self numberOfUntransferredFiles] + [self numberOfTransferredFiles] > 1) {
				if([self state] == WCTransferPaused)
					format = NSLS(@"Paused at %lu of %lu files, %@ of %@", @"Transfer paused (files, transferred, size)");
				else if([self state] == WCTransferStopped)
					format = NSLS(@"Stopped at %lu of %lu files, %@ of %@", @"Transfer stopped (files, transferred, size)");
				else
					format = NSLS(@"Disconnected at %lu of %lu files, %@ of %@", @"Transfer disconnected (files, transferred, size)");

				return [NSSWF:format,
					[self numberOfTransferredFiles],
					[self numberOfUntransferredFiles] + [self numberOfTransferredFiles],
					[NSString humanReadableStringForSizeInBytes:transferred],
					[NSString humanReadableStringForSizeInBytes:[self size]]];
			} else {
				if([self state] == WCTransferPaused)
					format = NSLS(@"Paused at %@ of %@", @"Transfer stopped (transferred, size)");
				else if([self state] == WCTransferStopped)
					format = NSLS(@"Stopped at %@ of %@", @"Transfer stopped (transferred, size)");
				else
					format = NSLS(@"Disconnected at %@ of %@", @"Transfer disconnected (transferred, size)");

				return [NSSWF:format,
					[NSString humanReadableStringForSizeInBytes:transferred],
					[NSString humanReadableStringForSizeInBytes:[self size]]];
			}
			break;
			
		case WCTransferFinished:
			transferred		= [self dataTransferred] + [self rsrcTransferred];
			interval		= _accumulatedTime;
			
			if(interval > 0.0)
				speed		= [NSSWF:@"%@/s", [NSString humanReadableStringForSizeInBytes:[self actualTransferred] / interval]];
			else
				speed		= [NSSWF:@"%@/s", [NSString humanReadableStringForSizeInBytes:0]];
			
			if(_speedLimit > 0) {
				speed		= [speed stringByAppendingFormat:@" (%@/s limit)",
					[NSString humanReadableStringForSizeInBytes:_speedLimit]];
			}

			if([self isFolder] && [self numberOfUntransferredFiles] + [self numberOfTransferredFiles] > 1) {
				return [NSSWF:NSLS(@"Finished %lu files, %@, average %@, took %@", @"Transfer finished (files, transferred, speed, time)"),
					[self numberOfTransferredFiles],
					[NSString humanReadableStringForSizeInBytes:transferred],
					speed,
					[NSString humanReadableStringForTimeInterval:_accumulatedTime]];
			} else {
				return [NSSWF:NSLS(@"Finished %@, average %@, took %@", @"Transfer finished (files, transferred, speed, time)"),
					[NSString humanReadableStringForSizeInBytes:transferred],
					speed,
					[NSString humanReadableStringForTimeInterval:_accumulatedTime]];
			}
			break;
	}
	
	return @"";
}



- (NSImage *)icon {
	if(!_icon) {
		if([self isFolder])
			_icon = [[WCFile iconForFolderType:WCFileDirectory width:32.0] retain];
		else
			_icon = [[_file iconWithWidth:32.0] copy];
	}
	
	return _icon;
}



- (void)refreshSpeedLimit {
	[self doesNotRecognizeSelector:_cmd];
}



#pragma mark -

- (BOOL)containsUntransferredFile:(WCFile *)file {
	return [_untransferredFilesSet containsObject:file];
}



- (BOOL)containsTransferredFile:(WCFile *)file {
	return [_transferredFilesSet containsObject:file];
}



- (BOOL)containsUncreatedDirectory:(WCFile *)directory {
	return [_uncreatedDirectoriesSet containsObject:directory];
}



- (BOOL)containsCreatedDirectory:(WCFile *)directory {
	return [_createdDirectoriesSet containsObject:directory];
}



#pragma mark -

- (NSUInteger)numberOfUntransferredFiles {
	return [_untransferredFilesList count];
}



- (NSUInteger)numberOfTransferredFiles {
	return [_transferredFilesList count];
}



- (WCFile *)firstUntransferredFile {
	if([_untransferredFilesList count] == 0)
		return NULL;
	
	return [_untransferredFilesList objectAtIndex:0];
}



- (void)addUntransferredFile:(WCFile *)file {
	[_untransferredFilesList addObject:file];
	[_untransferredFilesSet addObject:file];
}



- (void)removeUntransferredFile:(WCFile *)file {
	[_untransferredFilesList removeObject:file];
	[_untransferredFilesSet removeObject:file];
}



- (void)addTransferredFile:(WCFile *)file {
	[_transferredFilesList addObject:file];
	[_transferredFilesSet addObject:file];
}



- (void)removeTransferredFile:(WCFile *)file {
	[_transferredFilesList removeObject:file];
	[_transferredFilesSet removeObject:file];
}



#pragma mark -

- (void)addUncreatedDirectory:(WCFile *)directory {
	[_uncreatedDirectoriesList addObject:directory];
	[_uncreatedDirectoriesSet addObject:directory];
}



- (void)removeUncreatedDirectory:(WCFile *)directory {
	[_uncreatedDirectoriesList removeObject:directory];
	[_uncreatedDirectoriesSet removeObject:directory];
}



- (void)removeAllUncreatedDirectories {
	[_uncreatedDirectoriesList removeAllObjects];
	[_uncreatedDirectoriesSet removeAllObjects];
}



- (void)addCreatedDirectory:(WCFile *)directory {
	[_createdDirectoriesList addObject:directory];
	[_createdDirectoriesSet addObject:directory];
}



- (void)removeCreatedDirectory:(WCFile *)directory {
	[_createdDirectoriesList removeObject:directory];
	[_createdDirectoriesSet removeObject:directory];
}



- (NSArray *)uncreatedDirectories {
	return _uncreatedDirectoriesList;
}



- (NSArray *)createdDirectories {
	return _createdDirectoriesList;
}

@end



@implementation WCDownloadTransfer

- (void)refreshSpeedLimit {
	NSUInteger		serverLimit, accountLimit;
	
	serverLimit = [[[self connection] server] downloadSpeed];
	accountLimit = [[[self connection] account] transferDownloadSpeedLimit];
	
	_speedLimit = WI_MIN(serverLimit, accountLimit);
}

@end



@implementation WCPreviewTransfer

@end



@implementation WCUploadTransfer

- (void)refreshSpeedLimit {
	NSUInteger		serverLimit, accountLimit;
	
	serverLimit = [[[self connection] server] uploadSpeed];
	accountLimit = [[[self connection] account] transferUploadSpeedLimit];
	
	_speedLimit = WI_MIN(serverLimit, accountLimit);
}

@end
