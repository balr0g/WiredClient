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

#import "NSAlert-WCAdditions.h"
#import "WCCache.h"
#import "WCConnect.h"
#import "WCErrorQueue.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCPreferences.h"
#import "WCServer.h"
#import "WCServerConnection.h"
#import "WCServerInfo.h"
#import "WCStats.h"
#import "WCTransfer.h"
#import "WCTransferCell.h"
#import "WCTransferConnection.h"
#import "WCTransfers.h"

#define WCTransfersChecksumLength				1048576

#define WCTransfersFileExtension				@"WiredTransfer"
#define WCTransferConnectionKey					@"WCTransferConnectionKey"
#define WCTransferPboardType					@"WCTransferPboardType"

#define WCTransfersTextEditExtensionsString		@"c cc cgi conf css diff h in java log m patch pem php pl plist pod rb rtf s sh status strings tcl text txt xml"
#define WCTransfersSafariExtensionsString		@"htm html shtm shtml svg"
#define WCTransfersPreviewExtensionsString		@"bmp eps jpg jpeg tif tiff gif pct pict pdf png"


static NSMutableSet								*WCTransfersTextEditExtensions;
static NSMutableSet								*WCTransfersSafariExtensions;
static NSMutableSet								*WCTransfersPreviewExtensions;


static inline NSTimeInterval _WCTransfersTimeInterval(void) {
	struct timeval		tv;

	gettimeofday(&tv, NULL);

	return tv.tv_sec + ((double) tv.tv_usec / 1000000.0);
}


@interface WCTransfers(Private)

- (void)_validate;
- (void)_themeDidChange;
- (void)_reload;

- (void)_presentError:(WCError *)error forConnection:(WCServerConnection *)connection;

- (WCTransfer *)_selectedTransfer;
- (WCTransfer *)_unfinishedTransferWithPath:(NSString *)path;
- (WCTransfer *)_transferWithState:(WCTransferState)state;
- (WCTransfer *)_transferWithState:(WCTransferState)state class:(Class)class;
- (WCTransfer *)_transferWithTransaction:(NSUInteger)transaction;
- (NSUInteger)_numberOfWorkingTransfersOfClass:(Class)class connection:(WCServerConnection *)connection;

- (void)_requestNextTransferForConnection:(WCServerConnection *)connection;
- (void)_requestTransfer:(WCTransfer *)transfer;
- (void)_startTransfer:(WCTransfer *)transfer first:(BOOL)first;
- (void)_queueTransfer:(WCTransfer *)transfer; 
- (void)_createRemainingDirectoriesForTransfer:(WCTransfer *)transfer;
- (void)_invalidateTransfersForConnection:(WCServerConnection *)connection;
- (void)_saveTransfers;
- (void)_finishTransfer:(WCTransfer *)transfer;
- (void)_removeTransfer:(WCTransfer *)transfer;

- (BOOL)_downloadFile:(WCFile *)file toFolder:(NSString *)destination preview:(BOOL)preview;
- (BOOL)_uploadPath:(NSString *)path toFolder:(WCFile *)destination;

- (void)_runDownload:(WCTransfer *)transfer;
- (void)_runUpload:(WCTransfer *)transfer;

@end


@implementation WCTransfers(Private)

- (void)_validate {
	[[[self window] toolbar] validateVisibleItems];
}



- (void)_themeDidChange {
	NSDictionary		*theme;
	
	theme = [WCSettings themeWithIdentifier:[WCSettings objectForKey:WCTheme]];
	
	if([theme boolForKey:WCThemesTransferListShowProgressBar]) {
		[_transfersTableView setRowHeight:46.0];
		[[_infoTableColumn dataCell] setDrawsProgressIndicator:YES];
	} else {
		[_transfersTableView setRowHeight:34.0];
		[[_infoTableColumn dataCell] setDrawsProgressIndicator:NO];
	}
	
	[_transfersTableView setUsesAlternatingRowBackgroundColors:[theme boolForKey:WCThemesTransferListAlternateRows]];
}



- (void)_reload {
	[_transfersTableView reloadData];
	[_transfersTableView setNeedsDisplay:YES];
}



#pragma mark -

- (void)_presentError:(WCError *)error forConnection:(WCServerConnection *)connection {
	if(![[self window] isVisible])
		[self showWindow:self];
	
	[connection triggerEvent:WCEventsError info1:error];
	
	[[error alert] runNonModal];
}



#pragma mark -

- (WCTransfer *)_selectedTransfer {
	NSInteger		row;
	
	row = [_transfersTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_transfers objectAtIndex:row];
}



- (WCTransfer *)_unfinishedTransferWithPath:(NSString *)path {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer state] != WCTransferFinished) {
			if([transfer isFolder]) {
				if([[transfer remotePath] isEqualToString:path] ||
				   [path hasPrefix:[[transfer remotePath] stringByAppendingString:@"/"]])
					return transfer;
			} else {
				if([transfer containsFile:[WCFile fileWithFile:path connection:NULL]])
					return transfer;
			}
		}
	}

	return NULL;
}



- (WCTransfer *)_transferWithState:(WCTransferState)state {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer state] == state)
			return transfer;
	}

	return NULL;
}



- (WCTransfer *)_transferWithState:(WCTransferState)state class:(Class)class {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer state] == state && [transfer class] == class)
			return transfer;
	}

	return NULL;
}



- (WCTransfer *)_transferWithTransaction:(NSUInteger)transaction {
	WCTransfer			*transfer;
	NSUInteger			i, count;

	count = [_transfers count];
	
	for(i = 0; i < count; i++) {
		transfer = [_transfers objectAtIndex:i];
		
		if([transfer transaction] == transaction)
			return transfer;
	}
	
	return NULL;
}



- (NSUInteger)_numberOfWorkingTransfersOfClass:(Class)class connection:(WCServerConnection *)connection {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;
	NSUInteger			count = 0;

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer connection] == connection && [transfer class] == class && [transfer isWorking])
			count++;
	}

	return count;
}



#pragma mark -

- (BOOL)_downloadFile:(WCFile *)file toFolder:(NSString *)destination preview:(BOOL)preview {
	NSAlert					*alert;
	NSString				*path;
	WCDownloadTransfer		*transfer;
	WCError					*error;
	BOOL					isDirectory;
	NSUInteger				count;

	if([self _unfinishedTransferWithPath:[file path]]) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferExists argument:[file path]];
		[self _presentError:error forConnection:[file connection]];
		
		return NO;
	}

	path = [destination stringByAppendingPathComponent:[file name]];
	
	if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
		if(!(isDirectory && [file isFolder])) {
			alert = [[[NSAlert alloc] init] autorelease];
			[alert setMessageText:NSLS(@"File Exists", @"Transfers overwrite alert title")];
			[alert setInformativeText:[NSSWF:NSLS(@"The file \u201c%@\u201d already exists. Overwrite?", @"Transfers overwrite alert title"), path]];
			[alert addButtonWithTitle:NSLS(@"Cancel", @"Transfers overwrite alert button")];
			[alert addButtonWithTitle:NSLS(@"Overwrite", @"Transfers overwrite alert button")];
			
			if([alert runModal] == NSAlertFirstButtonReturn)
				return NO;
			
			[[NSFileManager defaultManager] removeFileAtPath:path handler:NULL];
		}
	}
	
	if(preview)
		transfer = [WCPreviewTransfer transferWithConnection:[file connection]];
	else
		transfer = [WCDownloadTransfer transferWithConnection:[file connection]];

	[transfer setDestinationPath:destination];
	[transfer setRemotePath:[file path]];
	[transfer setName:[file name]];
	
	if([file type] == WCFileFile) {
		if(![path hasSuffix:WCTransfersFileExtension])
			path = [path stringByAppendingPathExtension:WCTransfersFileExtension];

		[file setTransferred:[[NSFileManager defaultManager] fileSizeAtPath:path]];
		[file setLocalPath:path];
		
		[transfer setSize:[file size]];
		[transfer setFile:file];
		[transfer addFile:file];
		[transfer setTransferred:[[transfer firstFile] transferred]];
		[transfer setLocalPath:path];
	} else {
		[file setLocalPath:path];
		
		[transfer addDirectory:file];
		[transfer setFolder:YES];
		[transfer setLocalPath:path];
	}
	
	[_transfers addObject:transfer];
	
	[self _saveTransfers];

	count = [self _numberOfWorkingTransfersOfClass:[transfer class] connection:[file connection]];

	if(count == 1)
		[self showWindow:self];
	
	if(count > 1 && [WCSettings boolForKey:WCQueueTransfers])
		[transfer setState:WCTransferLocallyQueued];
	else
		[self _requestTransfer:transfer];
	
	[_transfersTableView reloadData];
	
	return YES;
}



- (BOOL)_uploadPath:(NSString *)path toFolder:(WCFile *)destination {
	NSDirectoryEnumerator	*enumerator;
	NSString				*eachPath, *remotePath, *localPath, *serverPath, *resourceForkPath = NULL;
	WCTransfer				*transfer;
	WCFile					*file;
	WCError					*error;
	NSUInteger				count;
	BOOL					isDirectory, hasResourceFork;
	
	remotePath = [[destination path] stringByAppendingPathComponent:[path lastPathComponent]];

	if([self _unfinishedTransferWithPath:remotePath]) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferExists argument:remotePath];
		[self _presentError:error forConnection:[destination connection]];
		
		return NO;
	}

	transfer = [WCUploadTransfer transferWithConnection:[destination connection]];
	[transfer setDestinationPath:[destination path]];
	[transfer setLocalPath:path];
	[transfer setName:[path lastPathComponent]];
	[transfer setRemotePath:remotePath];
	
	if([[NSFileManager defaultManager] directoryExistsAtPath:path]) {
		[transfer setFolder:YES];
		[transfer setState:WCTransferListing];
	}
	
	enumerator = [[NSFileManager defaultManager] enumeratorWithFileAtPath:path];
	count = 0;

	while((eachPath = [enumerator nextObject])) {
		if([[eachPath lastPathComponent] hasPrefix:@"."]) {
			[enumerator skipDescendents];
			
			continue;
		}

		if([transfer isFolder]) {
			localPath	= [[transfer localPath] stringByAppendingPathComponent:eachPath];
			serverPath	= [remotePath stringByAppendingPathComponent:eachPath];
		} else {
			localPath	= eachPath;
			serverPath	= remotePath;
		}

		if([[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory hasResourceFork:&hasResourceFork]) {
			if(isDirectory) {
				[transfer addDirectory:[WCFile fileWithDirectory:serverPath connection:[destination connection]]];
			} else {
				file = [WCFile fileWithFile:serverPath connection:[destination connection]];
				[file setSize:[[NSFileManager defaultManager] fileSizeAtPath:localPath]];
				[file setLocalPath:localPath];
				
				[transfer setSize:[transfer size] + [file size]];
				[transfer addFile:file];
				[transfer setTotalFiles:[transfer totalFiles] + 1];
				
				if(![transfer isFolder])
					[transfer setFile:file];
			}
			
			if(hasResourceFork) {
				resourceForkPath = localPath;
				count++;
			}
		}
	}
	
	if(count > 0 && [WCSettings boolForKey:WCCheckForResourceForks]) {
		if(count == 1)
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferWithResourceFork argument:resourceForkPath];
		else
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferWithResourceFork argument:[NSNumber numberWithInt:count]];
		
		[self _presentError:error forConnection:[destination connection]];
	}
	
	[_transfers addObject:transfer];
	
	[self _saveTransfers];

	count = [self _numberOfWorkingTransfersOfClass:[transfer class] connection:[destination connection]];
	
	if(count == 1)
		[self showWindow:self];
	
	if(count > 1 && [WCSettings boolForKey:WCQueueTransfers])
		[transfer setState:WCTransferLocallyQueued];
	else
		[self _requestTransfer:transfer];
	
	[_transfersTableView reloadData];
	
	return YES;
}



#pragma mark -

- (void)_requestNextTransferForConnection:(WCServerConnection *)connection {
	WCTransfer		*transfer = NULL;
	NSUInteger		downloads, uploads;
	
	if(![WCSettings boolForKey:WCQueueTransfers]) {
		transfer	= [self _transferWithState:WCTransferLocallyQueued];
	} else {
		downloads	= [self _numberOfWorkingTransfersOfClass:[WCDownloadTransfer class] connection:connection];
		uploads		= [self _numberOfWorkingTransfersOfClass:[WCUploadTransfer class] connection:connection];
		
		if(downloads == 0 && uploads == 0)
			transfer = [self _transferWithState:WCTransferLocallyQueued];
		else if(downloads == 0)
			transfer = [self _transferWithState:WCTransferLocallyQueued class:[WCDownloadTransfer class]];
		else if(uploads == 0)
			transfer = [self _transferWithState:WCTransferLocallyQueued class:[WCUploadTransfer class]];
		
	}

	if(transfer)
		[self _requestTransfer:transfer];
}



- (void)_requestTransfer:(WCTransfer *)transfer {
	NSString		*path;
	WIP7Message		*message;
	NSUInteger		transaction;
	
	if([transfer isFolder]) {
		[transfer setState:WCTransferListing];
		
		if([transfer isKindOfClass:[WCDownloadTransfer class]]) {
			path = [transfer remotePath];
		} else {
			path = [[transfer destinationPath] stringByAppendingPathComponent:
				[[transfer localPath] lastPathComponent]];

			message = [WIP7Message messageWithName:@"wired.transfer.upload_directory" spec:WCP7Spec];
			[message setString:[transfer remotePath] forName:@"wired.file.path"];
			[[transfer connection] sendMessage:message fromObserver:self selector:@selector(wiredTransferUploadDirectoryReply:)];
		}

		message = [WIP7Message messageWithName:@"wired.file.list_directory" spec:WCP7Spec];
		[message setString:path forName:@"wired.file.path"];
		[message setBool:YES forName:@"wired.file.recursive"];
		transaction = [[transfer connection] sendMessage:message fromObserver:self selector:@selector(wiredFileListPathReply:)];
		[transfer setTransaction:transaction];
	} else {
		[self _startTransfer:transfer first:YES];
	}
}



- (void)_startTransfer:(WCTransfer *)transfer first:(BOOL)first {
	[[transfer connection] triggerEvent:WCEventsTransferStarted info1:transfer];

	if(![transfer isTerminating])
		[transfer setState:WCTransferWaiting];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_queueTransfer:) object:transfer]; 

	[WIThread detachNewThreadSelector:@selector(transferThread:) toTarget:self withObject:transfer];
}



- (void)_queueTransfer:(WCTransfer *)transfer { 
	[transfer setState:WCTransferQueued]; 
	
	[_transfersTableView setNeedsDisplay:YES]; 
} 



- (void)_createRemainingDirectoriesForTransfer:(WCTransfer *)transfer {
	NSArray			*directories;
	WIP7Message		*message;
	NSUInteger		i, count;
	
	directories = [transfer directories];
	count = [directories count];
			
	for(i = 0; i < count; i++) {
		if([transfer isKindOfClass:[WCDownloadTransfer class]]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:[[directories objectAtIndex:i] localPath]];
		} else {
			message = [WIP7Message messageWithName:@"wired.transfer.upload_directory" spec:WCP7Spec];
			[message setString:[[directories objectAtIndex:i] path] forName:@"wired.file.path"];
			[[transfer connection] sendMessage:message fromObserver:self selector:@selector(wiredTransferUploadDirectoryReply:)];
		}
	}
	
	[transfer removeAllDirectories];
}



- (void)_invalidateTransfersForConnection:(WCServerConnection *)connection {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;
	
	enumerator = [_transfers objectEnumerator];
	
	while((transfer = [enumerator nextObject])) {
		if([transfer connection] == connection) {
			if([transfer isWorking])
				[transfer setState:WCTransferDisconnecting];
			
			[transfer setConnection:NULL];
		}
	}
}



- (void)_saveTransfers {
	NSEnumerator		*enumerator;
	NSMutableArray		*transfers;
	WCTransfer			*transfer;
	
	transfers = [NSMutableArray array];
	enumerator = [_transfers objectEnumerator];
	
	while((transfer = [enumerator nextObject])) {
		if(![transfer isWorking])
			[transfers addObject:transfer];
	}
	
	[WCSettings setObject:[NSKeyedArchiver archivedDataWithRootObject:transfers] forKey:WCTransferList];
}



- (void)_finishTransfer:(WCTransfer *)transfer {
	NSString			*path, *newPath, *extension;
	NSDictionary		*dictionary;
	WCFile				*file;
	WCTransferState		state;
	BOOL				next = YES;
	
	file = [[transfer firstFile] retain];
	path = [file localPath];
	
	if([file transferred] >= [file size]) {
		if([transfer isKindOfClass:[WCDownloadTransfer class]]) {
			newPath = [path stringByDeletingPathExtension];
			
			[[NSFileManager defaultManager] movePath:path toPath:newPath handler:NULL];
			[transfer setLocalPath:newPath];
			path = newPath;
			
			if([file isExecutable]) {
				dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0755] forKey:NSFilePosixPermissions];
				
				[[NSFileManager defaultManager] changeFileAttributes:dictionary atPath:path];
			}
		}
		
		[transfer setTransferredFiles:[transfer transferredFiles] + 1];
		[transfer removeFirstFile];
		
		if([transfer numberOfFiles] == 0) {
			[[transfer transferConnection] disconnect];
			[transfer setTransferConnection:NULL];
			[transfer setState:WCTransferFinished];
			[[transfer progressIndicator] setDoubleValue:1.0];
			
			if([WCSettings boolForKey:WCRemoveTransfers])
				[self _removeTransfer:transfer];

			[_transfersTableView reloadData];

			[self _validate];

			[[transfer connection] triggerEvent:WCEventsTransferFinished info1:transfer];
			
			extension = [[path pathExtension] lowercaseString];

			if([transfer isKindOfClass:[WCPreviewTransfer class]] && [[self class] canPreviewFileWithExtension:extension]) {
				
				if([WCTransfersTextEditExtensions containsObject:extension])
					[[NSWorkspace sharedWorkspace] openFile:path withApplication:@"/Applications/TextEdit.app"];
				else if([WCTransfersSafariExtensions containsObject:extension])
					[[NSWorkspace sharedWorkspace] openFile:path withApplication:@"/Applications/Safari.app"];
				else if([WCTransfersPreviewExtensions containsObject:extension])
					[[NSWorkspace sharedWorkspace] openFile:path withApplication:@"/Applications/Preview.app"];
			}
		} else {
			[self _startTransfer:transfer first:NO];

			next = NO;
		}
	} else {
		[[transfer transferConnection] disconnect];
		[transfer setTransferConnection:NULL];

		state = [transfer state];
		
		if(state == WCTransferPausing) {
			[transfer setState:WCTransferPaused];
			
			next = NO;
		}
		else if(state == WCTransferDisconnecting) {
			[transfer setState:WCTransferDisconnected];
			
			next = NO;
		}
		else if(state == WCTransferRemoving) {
			[self _removeTransfer:transfer];
		}
		else {
			[transfer setState:WCTransferStopped];
		}
		
		[_transfersTableView reloadData];
		
		[self _validate];
	}

	if(next)
		[self _requestNextTransferForConnection:[transfer connection]];
	
	[file release];
}



- (void)_removeTransfer:(WCTransfer *)transfer {
	[[transfer progressIndicator] removeFromSuperview];

	[_transfers removeObject:transfer];

	[self _saveTransfers];
}



#pragma mark -

- (BOOL)_connectConnection:(WCTransferConnection *)connection forTransfer:(WCTransfer *)transfer error:(WCError **)error {
	if(![connection connectWithTimeout:30.0 error:error])
		return NO;
	
	if(![connection writeMessage:[connection clientInfoMessage] timeout:30.0 error:error] ||
	   ![connection writeMessage:[connection setNickMessage] timeout:30.0 error:error] ||
	   ![connection writeMessage:[connection setStatusMessage] timeout:30.0 error:error] ||
	   ![connection writeMessage:[connection setIconMessage] timeout:30.0 error:error] ||
	   ![connection writeMessage:[connection loginMessage] timeout:30.0 error:error])
		return NO;
	
	return YES;
}



- (WIP7Message *)_runConnection:(WCTransferConnection *)connection forTransfer:(WCTransfer *)transfer untilReceivingMessageName:(NSString *)messageName error:(WCError **)error {
	NSString			*name;
	WIP7Message			*message, *reply;
	NSInteger			code;
	WIP7UInt32			queue, transaction;
	
	while([transfer isWorking]) {
		message = [connection readMessageWithTimeout:1.0 error:error];
	
		if(!message) {
			code = [[[*error userInfo] objectForKey:WILibWiredErrorKey] code];

			if(code == ETIMEDOUT)
				continue;

			return NULL;
		}
		
		name = [message name];
		
		if([name isEqualToString:messageName])
			return message;

		if([name isEqualToString:@"wired.transfer.queue"]) {
			[message getUInt32:&queue forName:@"wired.transfer.queue_position"];
			
			[transfer setQueuePosition:queue];

			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_queueTransfer:) object:transfer]; 

	        if([transfer state] == WCTransferRunning) 
				[self performSelector:@selector(_queueTransfer:) withObject:transfer afterDelay:0.5]; 
	        else 
				[self _queueTransfer:transfer]; 
		}
		else if([name isEqualToString:@"wired.send_ping"]) {
			reply = [WIP7Message messageWithName:@"wired.ping" spec:WCP7Spec];
			
			if([message getUInt32:&transaction forName:@"wired.transaction"])
				[reply setUInt32:transaction forName:@"wired.transaction"];
			
			if(![connection writeMessage:reply timeout:30.0 error:error])
				return NULL;
		}
		else if([name isEqualToString:@"wired.error"]) {
			*error = [WCError errorWithWiredMessage:message];
			
			return NULL;
		}
	}
	
	*error = NULL;
	
	return NULL;
}



- (void)_runDownload:(WCTransfer *)transfer {
	NSAutoreleasePool			*pool = NULL;
	NSProgressIndicator			*progressIndicator;
	NSString					*path;
	NSFileHandle				*fileHandle;
	WIP7Socket					*socket;
	WIP7Message					*message;
	WCTransferConnection		*connection;
	WCFile						*file;
	WCError						*error = NULL;
	void						*buffer;
	NSTimeInterval				time, speedTime, statsTime;
	NSUInteger					i, speedBytes, statsBytes;
	NSInteger					readBytes;
	WIP7UInt64					dataLength;
	WCTransferState				state;
	double						percent, speed, maxSpeed;
	int							fd, writtenBytes;
	
	file = [transfer firstFile];
	path = [file localPath];
	speedBytes = statsBytes = maxSpeed = 0;
	i = 0;
	connection = [transfer transferConnection];
	
	if(!connection) {
		connection = [WCTransferConnection connectionWithTransfer:transfer];
		[connection setURL:[[transfer connection] URL]];
		[connection setBookmark:[[transfer connection] bookmark]];
		
		if(![self _connectConnection:connection forTransfer:transfer error:&error]) {
			[transfer setState:WCTransferStopping];

			goto end;
		}
		
		[transfer setTransferConnection:connection];
	}
	
	[self _createRemainingDirectoriesForTransfer:transfer];
	
	message = [WIP7Message messageWithName:@"wired.transfer.download_file" spec:WCP7Spec];
	[message setString:[file path] forName:@"wired.file.path"];
	[message setUInt64:[file transferred] forName:@"wired.transfer.offset"];
	
	if(![connection writeMessage:message timeout:30.0 error:&error]) {
		[transfer setState:WCTransferStopping];
		
		goto end;
	}
	
	message = [self _runConnection:connection
					   forTransfer:transfer
		 untilReceivingMessageName:@"wired.transfer.download"
							 error:&error];
	
	if(!message) {
		[transfer setState:WCTransferStopping];
		
		goto end;
	}
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		if(![[NSFileManager defaultManager] createFileAtPath:path]) {
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientCreateFailed argument:path];
			
			[transfer setState:WCTransferStopping];

			goto end;
		}
	}
	
	fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
	
	if(!fileHandle) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];
		
		[transfer setState:WCTransferStopping];

		goto end;
	}
	
	[fileHandle seekToFileOffset:[file transferred]];
	
	state = [transfer state];
	
	if(![transfer isTerminating]) {
		[transfer setState:WCTransferRunning];
		
		[self performSelectorOnMainThread:@selector(_validate)];
	}
	
	socket = [connection socket];
	fd = [fileHandle fileDescriptor];
	speedTime = statsTime = _WCTransfersTimeInterval();
	progressIndicator = [transfer progressIndicator];
	
	[[socket socket] setInteractive:NO];
	[transfer setSecure:[socket usesEncryption]];

	[message getUInt64:&dataLength forName:@"wired.transfer.data"];
	
	pool = [[NSAutoreleasePool alloc] init];
	
	_running++;

	while(dataLength > 0) {
		if([transfer isTerminating])
			break;

		readBytes = [socket readOOBData:&buffer timeout:30.0 error:&error];
		
		if(readBytes <= 0) {
			[transfer setState:WCTransferDisconnecting];

			break;
		}
		
		if([transfer isTerminating])
			break;

		dataLength -= readBytes;
		
		if((NSInteger) dataLength < 0) {
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];
			
			break;
		}
		
		writtenBytes = write(fd, buffer, readBytes);
		
		if(writtenBytes <= 0) {
			if(writtenBytes < 0)
				error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];
			
			break;
		}
		
		transfer->_actualTransferred += readBytes;
		transfer->_transferred += readBytes;
		file->_transferred += readBytes;
		
		speedBytes += readBytes;
		statsBytes += readBytes;
		percent = transfer->_transferred / (double) transfer->_size;
	
		if(percent == 1.00 || percent - [progressIndicator doubleValue] >= 0.001)
			[progressIndicator setDoubleValue:percent];
	
		time = _WCTransfersTimeInterval();

		speed = speedBytes / (time - speedTime);
		transfer->_speed = speed;

		if(time - speedTime > 30.0) {
			if(speed > maxSpeed)
				maxSpeed = speed;
			
			speedBytes = 0;
			speedTime = time;
		}
		
		if(time - statsTime > 10.0) {
			[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsDownloaded];
			
			statsBytes = 0;
			statsTime = time;
		}
		
		if(++i % 100 == 0) {
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
		}
	}
	
	_running--;

end:
	if(error) {
		[self performSelectorOnMainThread:@selector(_presentError:forConnection:)
							   withObject:error
							   withObject:[transfer connection]];
	}

	[pool release];
	
	if(statsBytes > 0)
		[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsDownloaded];

	if([[WCStats stats] unsignedIntForKey:WCStatsMaxDownloadSpeed] < maxSpeed)
		[[WCStats stats] setUnsignedInt:maxSpeed forKey:WCStatsMaxDownloadSpeed];
	
	[transfer signalTerminated];
	
	[self performSelectorOnMainThread:@selector(_finishTransfer:) withObject:transfer];
}



- (void)_runUpload:(WCTransfer *)transfer {
	NSAutoreleasePool			*pool = NULL;
	NSProgressIndicator			*progressIndicator;
	NSString					*path;
	NSFileHandle				*fileHandle;
	WIP7Socket					*socket;
	WIP7Message					*message;
	WCTransferConnection		*connection;
	WCFile						*file;
	WCError						*error = NULL;
	char						buffer[8192];
	NSTimeInterval				time, speedTime, statsTime;
	NSUInteger					i, sendBytes, speedBytes, statsBytes;
	WIP7UInt64					dataLength, offset;
	WCTransferState				state;
	double						percent, speed, maxSpeed;
	ssize_t						readBytes;
	int							fd;
	
	file = [transfer firstFile];
	path = [file localPath];
	speedBytes = statsBytes = maxSpeed = 0;
	i = 0;
	connection = [transfer transferConnection];
	
	if(!connection) {
		connection = [WCTransferConnection connectionWithTransfer:transfer];
		[connection setURL:[[transfer connection] URL]];
		[connection setBookmark:[[transfer connection] bookmark]];
		
		if(![self _connectConnection:connection forTransfer:transfer error:&error]) {
			[transfer setState:WCTransferStopping];

			goto end;
		}
		
		[transfer setTransferConnection:connection];
	}
	
	[self _createRemainingDirectoriesForTransfer:transfer];

	message = [WIP7Message messageWithName:@"wired.transfer.upload_file" spec:WCP7Spec];
	[message setString:[file path] forName:@"wired.file.path"];
	[message setUInt64:[file size] forName:@"wired.file.size"];
	
	if([[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] filePosixPermissions] & 0111)
		[message setBool:YES forName:@"wired.file.executable"];
	
	if(![connection writeMessage:message timeout:30.0 error:&error]) {
		[transfer setState:WCTransferStopping];

		goto end;
	}
	
	message = [self _runConnection:connection
					   forTransfer:transfer
		 untilReceivingMessageName:@"wired.transfer.upload_ready"
							 error:&error];
	
	if(!message) {
		[transfer setState:WCTransferStopping];

		goto end;
	}
	
	[message getUInt64:&offset forName:@"wired.transfer.offset"];
	
	dataLength = [file size] - offset;
	[file setTransferred:[file transferred] + offset];
	[transfer setTransferred:[transfer transferred] + offset];
	
	message = [WIP7Message messageWithName:@"wired.transfer.upload" spec:WCP7Spec];
	[message setString:[[transfer firstFile] path] forName:@"wired.file.path"];
	[message setUInt64:dataLength forName:@"wired.transfer.data"];
	
	if(![connection writeMessage:message timeout:30.0 error:&error]) {
		[transfer setState:WCTransferStopping];
		
		goto end;
	}

	fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
	
	if(!fileHandle) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];
		
		[transfer setState:WCTransferStopping];

		goto end;
	}

	[fileHandle seekToFileOffset:[file transferred]];

	state = [transfer state];
	
	if(![transfer isTerminating]) {
		[transfer setState:WCTransferRunning];
		
		[self performSelectorOnMainThread:@selector(_validate)];
	}

	socket = [connection socket];
	fd = [fileHandle fileDescriptor];
	speedTime = statsTime = _WCTransfersTimeInterval();
	progressIndicator = [transfer progressIndicator];
	
	[[socket socket] setInteractive:NO];
	[transfer setSecure:[socket usesEncryption]];

	pool = [[NSAutoreleasePool alloc] init];

	_running++;

	while(dataLength > 0) {
		if([transfer isTerminating])
			break;

		readBytes = read(fd, buffer, sizeof(buffer));

		if(readBytes <= 0) {
			if(readBytes < 0)
				error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];

			[transfer setState:WCTransferStopping];
			
			break;
		}
		
		sendBytes = (dataLength < (NSUInteger) readBytes) ? dataLength : (NSUInteger) readBytes;
		
		if(![socket writeOOBData:buffer length:sendBytes timeout:30.0 error:&error]) {
			[transfer setState:WCTransferDisconnecting];

			break;
		}

		transfer->_actualTransferred += readBytes;
		transfer->_transferred += sendBytes;
		file->_transferred += sendBytes;
		
		speedBytes += sendBytes;
		statsBytes += sendBytes;
		dataLength -= sendBytes;
		percent = transfer->_transferred / (double) transfer->_size;
		
		if(percent == 1.00 || percent - [progressIndicator doubleValue] >= 0.001)
			[progressIndicator setDoubleValue:percent];
		
		time = _WCTransfersTimeInterval();

		speed = speedBytes / (time - speedTime);
		transfer->_speed = speed;

		if(time - speedTime > 30.0) {
			if(speed > maxSpeed)
				maxSpeed = speed;

			speedBytes = 0;
			speedTime = time;
		}

		if(time - statsTime > 10.0) {
			[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsUploaded];

			statsBytes = 0;
			statsTime = time;
		}

		if(++i % 100 == 0) {
			[pool release];
			pool = NULL;
		}
	}
	
	_running--;
	
end:
	if(error) {
		[self performSelectorOnMainThread:@selector(_presentError:forConnection:)
							   withObject:error
							   withObject:[transfer connection]];
	}

	[pool release];
	
	if(statsBytes > 0)
		[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsDownloaded];

	if([[WCStats stats] unsignedIntForKey:WCStatsMaxDownloadSpeed] < maxSpeed)
		[[WCStats stats] setUnsignedInt:maxSpeed forKey:WCStatsMaxDownloadSpeed];
	
	[transfer signalTerminated];

	[self performSelectorOnMainThread:@selector(_finishTransfer:) withObject:transfer];
}

@end


@implementation WCTransfers

+ (BOOL)canPreviewFileWithExtension:(NSString *)extension {
	static NSMutableSet		*extensions;
					
	if(!WCTransfersTextEditExtensions) {
		WCTransfersTextEditExtensions = [[NSSet alloc] initWithArray:
			[WCTransfersTextEditExtensionsString componentsSeparatedByString:@" "]];

		WCTransfersSafariExtensions = [[NSSet alloc] initWithArray:
			[WCTransfersSafariExtensionsString componentsSeparatedByString:@" "]];

		WCTransfersPreviewExtensions = [[NSSet alloc] initWithArray:
			[WCTransfersPreviewExtensionsString componentsSeparatedByString:@" "]];
	}
	
	if(!extensions) {
		extensions = [[NSMutableSet alloc] init];
		
		[extensions unionSet:WCTransfersTextEditExtensions];
		[extensions unionSet:WCTransfersSafariExtensions];
		[extensions unionSet:WCTransfersPreviewExtensions];
	}
	
	return [extensions containsObject:[extension lowercaseString]];
}



#pragma mark -

+ (id)transfers {
	static WCTransfers   *sharedTransfers;
	
	if(!sharedTransfers)
		sharedTransfers = [[self alloc] init];
	
	return sharedTransfers;
}



#pragma mark -

- (id)init {
	self = [super initWithWindowNibName:@"Transfers"];

	_folderImage	= [[NSImage imageNamed:@"Folder"] retain];
	_lockedImage	= [[NSImage imageNamed:@"Locked"] retain];
	_unlockedImage	= [[NSImage imageNamed:@"Unlocked"] retain];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(selectedThemeDidChange:)
			   name:WCSelectedThemeDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionLoggedIn:)
			   name:WCLinkConnectionLoggedInNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionWillDisconnect:)
			   name:WCLinkConnectionWillDisconnectNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionDidClose:)
			   name:WCLinkConnectionDidCloseNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionDidTerminate:)
			   name:WCLinkConnectionDidTerminateNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(serverConnectionPrivilegesDidChange:)
			   name:WCServerConnectionPrivilegesDidChangeNotification];

	_timer = [NSTimer scheduledTimerWithTimeInterval:0.33
											  target:self
											selector:@selector(updateTimer:)
											userInfo:NULL
											 repeats:YES];
	[_timer retain];
	
	[self window];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_errorQueue release];
	
	[_timer release];

	[_folderImage release];
	[_lockedImage release];
	[_unlockedImage release];

	[_transfers release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar		*toolbar;
	NSData			*data;
	
	_errorQueue = [[WCErrorQueue alloc] initWithWindow:[self window]];
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Transfers"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];
	
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Transfers"];

	[_transfersTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:NSStringPboardType, WCTransferPboardType, NULL]];

    data = [WCSettings objectForKey:WCTransferList];

    if(data)
        _transfers = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
	
	if(!_transfers)
		_transfers = [[NSMutableArray alloc] init];
	
	[_transfersTableView reloadData];

	[self _themeDidChange];
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"Start"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Start", @"Start transfer toolbar item")
												content:[NSImage imageNamed:@"Start"]
												 target:self
												 action:@selector(start:)];
	}
	else if([identifier isEqualToString:@"Pause"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Pause", @"Pause transfer toolbar item")
												content:[NSImage imageNamed:@"Pause"]
												 target:self
												 action:@selector(pause:)];
	}
	else if([identifier isEqualToString:@"Stop"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Stop", @"Stop transfer toolbar item")
												content:[NSImage imageNamed:@"Stop"]
												 target:self
												 action:@selector(stop:)];
	}
	else if([identifier isEqualToString:@"Remove"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Remove", @"Remove transfer toolbar item")
												content:[NSImage imageNamed:@"Remove"]
												 target:self
												 action:@selector(remove:)];
	}
	else if([identifier isEqualToString:@"Clear"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Clear", @"Clear transfers toolbar item")
												content:[NSImage imageNamed:@"Remove"]
												 target:self
												 action:@selector(clear:)];
	}
	else if([identifier isEqualToString:@"Connect"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Connect", @"Connect transfer toolbar item")
												content:[NSImage imageNamed:@"Connect"]
												 target:self
												 action:@selector(connect:)];
	}
	else if([identifier isEqualToString:@"RevealInFinder"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reveal In Finder", @"Reveal transfer in Finder toolbar item")
												content:[NSImage imageNamed:@"RevealInFinder"]
												 target:self
												 action:@selector(revealInFinder:)];
	}
	else if([identifier isEqualToString:@"RevealInFiles"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reveal In Files", @"Reveal transfer in files toolbar item")
												content:[NSImage imageNamed:@"Folder"]
												 target:self
												 action:@selector(revealInFiles:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Start",
		@"Pause",
		@"Stop",
		@"Remove",
		@"Clear",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"Connect",
		@"RevealInFinder",
		@"RevealInFiles",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Start",
		@"Pause",
		@"Stop",
		@"Remove",
		@"Clear",
		@"Connect",
		@"RevealInFinder",
		@"RevealInFiles",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	NSEnumerator		*enumerator;
	NSMutableArray		*transfers;
	WCTransfer			*transfer;

	transfers = [NSMutableArray array];
	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer isWorking]) {
			[transfer setState:WCTransferDisconnecting];
			
			if([transfer waitUntilTerminatedBeforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]])
				[transfer setState:WCTransferDisconnected];
		}
	}

	[self _saveTransfers];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	NSEnumerator			*enumerator;
	WCServerConnection		*connection;
	WCTransfer				*transfer;

	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;

	connection = [notification object];
	enumerator = [_transfers objectEnumerator];
	
	while((transfer = [enumerator nextObject])) {
		if([transfer belongsToConnection:connection])
			[transfer setConnection:connection];
		
		if([transfer connection] == connection && [transfer state] == WCTransferDisconnected)
			[self _requestTransfer:transfer];
	}
	
	[_transfersTableView setNeedsDisplay:YES];
	[_transfersTableView reloadData];
	
	[self _validate];
}



- (void)linkConnectionWillDisconnect:(NSNotification *)notification {
	NSEnumerator			*enumerator;
	WCServerConnection		*connection;
	WCTransfer				*transfer;
	
	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;

	connection = [notification object];
	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer connection] == connection && [transfer isWorking])
			[transfer setState:WCTransferDisconnecting];
	}
	
	[_transfersTableView setNeedsDisplay:YES];
	[_transfersTableView reloadData];
	
	[self _validate];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;
	
	[self _invalidateTransfersForConnection:[notification object]];
	
	[self _validate];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;
	
	[self _invalidateTransfersForConnection:[notification object]];
	
	[self _validate];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	NSEnumerator			*enumerator;
	WCServerConnection		*connection;
	WCTransfer				*transfer;
	
	connection = [notification object];
	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer connection] == connection)
			[transfer refreshSpeedLimit];
	}
	
	[_transfersTableView setNeedsDisplay:YES];
}



- (void)selectedThemeDidChange:(NSNotification *)notification {
	[self _themeDidChange];
}



- (void)wiredFileListPathReply:(WIP7Message *)message {
	NSString			*rootPath, *localPath;
	WCTransfer			*transfer;
	WCFile				*file;
	NSRect				rect;
	WIP7UInt32			transaction;
	
	[message getUInt32:&transaction forName:@"wired.transaction"];

	transfer = [self _transferWithTransaction:transaction];

	if(!transfer)
		return;

	if([[message name] isEqualToString:@"wired.file.list"]) {
		file = [WCFile fileWithMessage:message connection:[transfer connection]];
		
		if([transfer isKindOfClass:[WCDownloadTransfer class]]) {
			rootPath = [[transfer remotePath] stringByDeletingLastPathComponent];
			localPath = [[transfer destinationPath] stringByAppendingPathComponent:
				[[file path] substringFromIndex:[rootPath length]]];
			
			if([file type] == WCFileFile) {
				[transfer setSize:[transfer size] + [file size]];
				[transfer setTotalFiles:[transfer totalFiles] + 1];
				
				if([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
					[transfer setTransferred:[transfer transferred] + [file size]];
					[transfer setTransferredFiles:[transfer transferredFiles] + 1];
				} else {
					if(![localPath hasSuffix:WCTransfersFileExtension])
						localPath = [localPath stringByAppendingPathExtension:WCTransfersFileExtension];

					[file setTransferred:[[NSFileManager defaultManager] fileSizeAtPath:localPath]];
					[file setLocalPath:localPath];
					
					[transfer addFile:file];
					[transfer setTransferred:[transfer transferred] + [file transferred]];
				}
			} else {
				if(![[NSFileManager defaultManager] directoryExistsAtPath:localPath]) {
					[file setLocalPath:localPath];
					[transfer addDirectory:file];
				}
			}
		} else {
			if([file type] == WCFileFile) {
				if([transfer containsFile:file]) {
					[transfer setTransferred:[transfer transferred] + [file size]];
					[transfer setTransferredFiles:[transfer transferredFiles] + 1];
					[transfer removeFile:file];
				}
			} else {
				[transfer removeDirectory:file];
			}
		}
		
		if([transfer totalFiles] % 10 == 0) {
			rect = [_transfersTableView frameOfCellAtColumn:1 row:[_transfers indexOfObject:transfer]];

			[_transfersTableView setNeedsDisplayInRect:rect];
		}
	}
	else if([[message name] isEqualToString:@"wired.file.list.done"]) {
		if([transfer numberOfFiles] > 0) {
			[self _startTransfer:transfer first:YES];
		} else {
			[self _createRemainingDirectoriesForTransfer:transfer];
			[self _finishTransfer:transfer];
		}
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
	}
}



- (void)wiredTransferUploadDirectoryReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



#pragma mark -

- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	WCTransfer			*transfer;
	SEL					selector;
	BOOL				connected;
	
	selector = [item action];
	transfer = [self _selectedTransfer];
	connected = [[transfer connection] isConnected];
	
	if(selector == @selector(start:) || selector == @selector(pause:) || selector == @selector(stop:)) {
		if(!transfer)
			return NO;
		
		switch([transfer state]) {
			case WCTransferLocallyQueued:
			case WCTransferPaused:
			case WCTransferStopped:
			case WCTransferDisconnected:
				if(selector == @selector(start:))
					return YES;
				else
					return NO;
				break;

			case WCTransferRunning:
				if(selector == @selector(start:))
					return NO;
				else
					return YES;
				break;

			default:
				return NO;
				break;
		}
	}
	else if(selector == @selector(remove:))
		return (transfer != NULL);
	else if(selector == @selector(clear:))
		return ([self _transferWithState:WCTransferFinished] != NULL);
	else if(selector == @selector(connect:))
		return (transfer && [transfer state] == WCTransferDisconnected);
	else if(selector == @selector(revealInFinder:))
		return (transfer && ![transfer isKindOfClass:[WCPreviewTransfer class]]);
	else if(selector == @selector(revealInFiles:))
		return (transfer != NULL && connected);
	
	
	return YES;
}



#pragma mark -

- (void)transferThread:(id)arg {
	NSAutoreleasePool		*pool;
	WCTransfer				*transfer = arg;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	if([transfer isKindOfClass:[WCDownloadTransfer class]])
		[self _runDownload:transfer];
	else
		[self _runUpload:transfer];
	
	[pool release];
}



- (void)updateTimer:(NSTimer *)timer {
	NSRect				rect;
	WCTransferState		state;
	NSUInteger			i, count;
	
	if(_running > 0) {
		count = [_transfers count];
		
		for(i = 0; i < count; i++) {
			state = [(WCTransfer *) [_transfers objectAtIndex:i] state];

			if(state == WCTransferRunning) {
				rect = [_transfersTableView frameOfCellAtColumn:1 row:i];

				[_transfersTableView setNeedsDisplayInRect:rect];
			}
		}
	}
}



#pragma mark -

- (BOOL)downloadFile:(WCFile *)file {
	return [self _downloadFile:file toFolder:[[WCSettings objectForKey:WCDownloadFolder] stringByStandardizingPath] preview:NO];
}



- (BOOL)downloadFile:(WCFile *)file toFolder:(NSString *)destination {
	return [self _downloadFile:file toFolder:destination preview:NO];
}



- (BOOL)previewFile:(WCFile *)file {
	return [self _downloadFile:file toFolder:[[WCSettings objectForKey:WCDownloadFolder] stringByStandardizingPath] preview:YES];
}



- (BOOL)uploadPath:(NSString *)path toFolder:(WCFile *)destination {
	return [self _uploadPath:path toFolder:destination];
}



#pragma mark -

- (IBAction)start:(id)sender {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	if([transfer state] != WCTransferRunning) {
		[transfer setState:WCTransferWaiting];
		
		[self _requestTransfer:transfer];
	}
		
	[_transfersTableView setNeedsDisplay:YES];

	[self _validate];
}



- (IBAction)pause:(id)sender {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	if([transfer state] == WCTransferRunning)
		[transfer setState:WCTransferPausing];
	
	[_transfersTableView setNeedsDisplay:YES];

	[self _validate];
}



- (IBAction)stop:(id)sender {
	[[self _selectedTransfer] setState:WCTransferStopping];

	[_transfersTableView setNeedsDisplay:YES];

	[self _validate];
}



- (IBAction)remove:(id)sender {
	WCTransfer		*transfer;

	transfer = [self _selectedTransfer];
	
	if([transfer isWorking])
		[transfer setState:WCTransferRemoving];
	else
		[self _removeTransfer:transfer];

	[_transfersTableView setNeedsDisplay:YES];
	[_transfersTableView reloadData];
	
	[self _validate];
}



- (IBAction)clear:(id)sender {
	WCTransfer		*transfer;

	while((transfer = [self _transferWithState:WCTransferFinished]))
		[self _removeTransfer:transfer];

	[_transfersTableView setNeedsDisplay:YES];
	[_transfersTableView reloadData];
	
	[self _validate];
}



- (IBAction)connect:(id)sender {
	WCConnect		*connect;
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	connect = [WCConnect connectWithURL:[transfer URL] bookmark:[transfer bookmark]];
	[connect showWindow:self];
	[connect connect:self];
}



- (IBAction)revealInFinder:(id)sender {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	[[NSWorkspace sharedWorkspace] selectFile:[transfer localPath] inFileViewerRootedAtPath:NULL];
}



- (IBAction)revealInFiles:(id)sender {
	WCTransfer		*transfer;
	NSString		*path;
	
	transfer = [self _selectedTransfer];
	path = [transfer remotePath];
	
	[WCFiles filesWithConnection:[transfer connection]
							path:[WCFile fileWithDirectory:[path stringByDeletingLastPathComponent] connection:[transfer connection]]
					  selectPath:path];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_transfers count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSImage			*icon;
	WCTransfer		*transfer;

	transfer = [_transfers objectAtIndex:row];

	if(tableColumn == _iconTableColumn) {
		return [transfer icon];
	}
	else if(tableColumn == _infoTableColumn) {
		icon = [transfer isSecure] ? _lockedImage : _unlockedImage;
	
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[transfer name],				WCTransferCellNameKey,
			[transfer status],				WCTransferCellStatusKey,
			icon,							WCTransferCellIconKey,
			[transfer progressIndicator],	WCTransferCellProgressKey,
			NULL];
	}

	return NULL;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self _validate];
}



- (void)tableViewFlagsDidChange:(NSTableView *)tableView {
	[self _validate];
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	NSString		*string;
	WCTransfer		*transfer;

	transfer = [self _selectedTransfer];
	
	if(!transfer)
		return;

	string = [NSSWF:@"%@ - %@", [transfer name], [transfer status]];

	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:string forType:NSStringPboardType];
}



- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
	if(operation != NSTableViewDropAbove)
		return NSDragOperationNone;

	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
	WCTransfer		*transfer;
	NSString		*string;
	NSUInteger		index;

	index		= [indexes firstIndex];
	transfer	= [_transfers objectAtIndex:index];
	string		= [NSSWF:@"%@ - %@", [transfer name], [transfer status]];

	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, WCTransferPboardType, NULL] owner:NULL];
	[pasteboard setString:[NSSWF:@"%ld", index] forType:WCTransferPboardType];
	[pasteboard setString:string forType:NSStringPboardType];

	return YES;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSArray			*types;
	NSInteger		fromRow;

	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];

	if([types containsObject:WCTransferPboardType]) {
		fromRow = [[pasteboard stringForType:WCTransferPboardType] integerValue];
		[_transfers moveObjectAtIndex:fromRow toIndex:row];
		[_transfersTableView reloadData];

		return YES;
	}

	return NO;
}

@end
