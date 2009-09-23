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

#define WCTransfersFileExtension				@"WiredTransfer"
#define WCTransfersFileExtendedAttributeName	@"com.zankasoftware.WiredTransfer"
#define WCTransferPboardType					@"WCTransferPboardType"


static inline NSTimeInterval _WCTransfersTimeInterval(void) {
	struct timeval		tv;

	gettimeofday(&tv, NULL);

	return tv.tv_sec + ((double) tv.tv_usec / 1000000.0);
}


@interface WCTransfers(Private)

- (void)_validate;
- (BOOL)_validateStart;
- (BOOL)_validatePause;
- (BOOL)_validateStop;
- (BOOL)_validateRemove;
- (BOOL)_validateClear;
- (BOOL)_validateConnect;
- (BOOL)_validateQuickLook;
- (BOOL)_validateRevealInFinder;
- (BOOL)_validateRevealInFiles;

- (void)_themeDidChange;
- (void)_reload;

- (void)_presentError:(WCError *)error forConnection:(WCServerConnection *)connection transfer:(WCTransfer *)transfer;

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

- (BOOL)_downloadFile:(WCFile *)file toFolder:(NSString *)destination;
- (BOOL)_uploadPath:(NSString *)path toFolder:(WCFile *)destination;

- (WCTransferConnection *)_transferConnectionForTransfer:(WCTransfer *)transfer;
- (BOOL)_sendDownloadFileMessageOnConnection:(WCTransferConnection *)connection forFile:(WCFile *)file error:(WCError **)error;
- (BOOL)_sendUploadFileMessageOnConnection:(WCTransferConnection *)connection forFile:(WCFile *)file error:(WCError **)error;
- (BOOL)_sendUploadMessageOnConnection:(WCTransferConnection *)connection forFile:(WCFile *)file dataLength:(WIFileOffset)dataLength rsrcLength:(WIFileOffset)rsrcLength error:(WCError **)error;
- (BOOL)_createRemainingDirectoriesOnConnection:(WCTransferConnection *)connection forTransfer:(WCTransfer *)transfer error:(WCError **)error;
- (BOOL)_connectConnection:(WCTransferConnection *)connection forTransfer:(WCTransfer *)transfer error:(WCError **)error;
- (WIP7Message *)_runConnection:(WCTransferConnection *)connection forTransfer:(WCTransfer *)transfer untilReceivingMessageName:(NSString *)messageName error:(WCError **)error;
- (void)_runDownload:(WCTransfer *)transfer;
- (void)_runUpload:(WCTransfer *)transfer;

@end


@implementation WCTransfers(Private)

- (void)_validate {
	[_startButton setEnabled:[self _validateStart]];
	[_pauseButton setEnabled:[self _validatePause]];
	[_stopButton setEnabled:[self _validateStop]];
	[_removeButton setEnabled:[self _validateRemove]];
	[_clearButton setEnabled:[self _validateClear]];
	
	[_connectButton setEnabled:[self _validateConnect]];
	[_quickLookButton setEnabled:[self _validateQuickLook]];
	[_revealInFinderButton setEnabled:[self _validateRevealInFinder]];
	[_revealInFilesButton setEnabled:[self _validateRevealInFiles]];

	[[[self window] toolbar] validateVisibleItems];
}



- (BOOL)_validateStart {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	if(!transfer || ![transfer connection] || ![[transfer connection] isConnected])
		return NO;
	
	switch([transfer state]) {
		case WCTransferLocallyQueued:
		case WCTransferPaused:
		case WCTransferStopped:
		case WCTransferDisconnected:
			return YES;
			break;
			
		default:
			return NO;
			break;
	}
}



- (BOOL)_validatePause {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	if(!transfer || ![transfer connection] || ![[transfer connection] isConnected])
		return NO;
	
	return ([transfer state] == WCTransferRunning);
}



- (BOOL)_validateStop {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	if(!transfer || ![transfer connection] || ![[transfer connection] isConnected])
		return NO;
	
	return ([transfer state] == WCTransferRunning);
}



- (BOOL)_validateRemove {
	return ([self _selectedTransfer] != NULL);
}



- (BOOL)_validateClear {
	return ([self _transferWithState:WCTransferFinished] != NULL);
}



- (BOOL)_validateConnect {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	return (transfer != NULL && [transfer connection] == NULL);
}



- (BOOL)_validateQuickLook {
	return ([self _selectedTransfer] != NULL && _quickLookPanelClass != NULL);
}



- (BOOL)_validateRevealInFinder {
	return ([self _selectedTransfer] != NULL);
}



- (BOOL)_validateRevealInFiles {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	return (transfer != NULL && [transfer connection] != NULL && [[transfer connection] isConnected]);
}



- (void)_themeDidChange {
	NSDictionary		*theme;
	
	theme = [[WCSettings settings] themeWithIdentifier:[[WCSettings settings] objectForKey:WCTheme]];
	
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

- (void)_presentError:(WCError *)error forConnection:(WCServerConnection *)connection transfer:(WCTransfer *)transfer {
	if(![[self window] isVisible])
		[self showWindow:self];
	
	[connection triggerEvent:WCEventsError info1:error];
	
	[_errorQueue showError:error withIdentifier:[transfer identifier]];
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
				if([transfer containsUntransferredFile:[WCFile fileWithFile:path connection:NULL]])
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

- (BOOL)_downloadFile:(WCFile *)file toFolder:(NSString *)destination {
	NSAlert					*alert;
	NSString				*path;
	WCDownloadTransfer		*transfer;
	WCError					*error;
	BOOL					isDirectory;
	NSUInteger				count;

	if([self _unfinishedTransferWithPath:[file path]]) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferExists argument:[file path]];
		[self _presentError:error forConnection:[file connection] transfer:NULL];
		
		return NO;
	}

	path = [destination stringByAppendingPathComponent:[file name]];
	
	if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
		if(!(isDirectory && [file isFolder])) {
			alert = [[[NSAlert alloc] init] autorelease];
			[alert setMessageText:NSLS(@"File Exists", @"Transfers overwrite alert title")];
			[alert setInformativeText:[NSSWF:NSLS(@"The file \u201c%@\u201d already exists. Overwrite?",
												  @"Transfers overwrite alert title"), path]];
			[alert addButtonWithTitle:NSLS(@"Cancel", @"Transfers overwrite alert button")];
			[alert addButtonWithTitle:NSLS(@"Overwrite", @"Transfers overwrite alert button")];
			
			if([alert runModal] == NSAlertFirstButtonReturn)
				return NO;
			
			[[NSFileManager defaultManager] removeFileAtPath:path handler:NULL];
		}
	}
	
	transfer = [WCDownloadTransfer transferWithConnection:[file connection]];
	[transfer setDestinationPath:destination];
	[transfer setRemotePath:[file path]];
	[transfer setName:[file name]];
	
	if([file type] == WCFileFile) {
		if(![path hasSuffix:WCTransfersFileExtension])
			path = [path stringByAppendingPathExtension:WCTransfersFileExtension];

		[file setDataTransferred:[[NSFileManager defaultManager] fileSizeAtPath:path]];
		
		if([[file connection] supportsResourceForks])
			[file setRsrcTransferred:[[NSFileManager defaultManager] resourceForkSizeAtPath:path]];
		
		[file setTransferLocalPath:path];
		
		[transfer setSize:[file dataSize] + [file rsrcSize]];
		[transfer setFile:file];
		[transfer addUntransferredFile:file];
		[transfer setDataTransferred:[[transfer firstUntransferredFile] dataTransferred]];
		[transfer setRsrcTransferred:[[transfer firstUntransferredFile] rsrcTransferred]];
		[transfer setLocalPath:path];
	} else {
		[file setTransferLocalPath:path];
		
		[transfer addUncreatedDirectory:file];
		[transfer setFolder:YES];
		[transfer setLocalPath:path];
	}
	
	[_transfers addObject:transfer];
	
	[self _saveTransfers];

	count = [self _numberOfWorkingTransfersOfClass:[transfer class] connection:[file connection]];

	if(count == 1)
		[self showWindow:self];
	
	if(count > 1 && [[WCSettings settings] boolForKey:WCQueueTransfers])
		[transfer setState:WCTransferLocallyQueued];
	else
		[self _requestTransfer:transfer];
	
	[_transfersTableView reloadData];
	
	return YES;
}



- (BOOL)_uploadPath:(NSString *)path toFolder:(WCFile *)destination {
	NSDirectoryEnumerator	*enumerator;
	NSString				*eachPath, *remotePath, *localPath, *serverPath, *resourceForkPath;
	WCTransfer				*transfer;
	WCFile					*file;
	WCError					*error;
	WIFileOffset			size;
	NSUInteger				count, resourceForks;
	BOOL					isDirectory;
	
	remotePath = [[destination path] stringByAppendingPathComponent:[path lastPathComponent]];

	if([self _unfinishedTransferWithPath:remotePath]) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferExists argument:remotePath];
		[self _presentError:error forConnection:[destination connection] transfer:NULL];
		
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
	
	enumerator			= [[NSFileManager defaultManager] enumeratorWithFileAtPath:path];
	resourceForks		= 0;
	resourceForkPath	= NULL;

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

		if([[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory]) {
			if(isDirectory) {
				[transfer addUncreatedDirectory:[WCFile fileWithDirectory:serverPath connection:[destination connection]]];
			} else {
				file = [WCFile fileWithFile:serverPath connection:[destination connection]];
				[file setUploadDataSize:[[NSFileManager defaultManager] fileSizeAtPath:localPath]];
				
				size = [[NSFileManager defaultManager] resourceForkSizeAtPath:localPath];
				
				if(size > 0) {
					if([[destination connection] supportsResourceForks]) {
						[file setUploadRsrcSize:size];
					} else {
						resourceForkPath = localPath;
						resourceForks++;
					}
				}
				
				[file setTransferLocalPath:localPath];
				
				[transfer setSize:[transfer size] + [file uploadDataSize]];
				
				if([[destination connection] supportsResourceForks])
					[transfer setSize:[transfer size] + [file uploadRsrcSize]];
				
				[transfer addUntransferredFile:file];
				
				if(![transfer isFolder])
					[transfer setFile:file];
			}
		}
	}
	
	[_transfers addObject:transfer];
	
	[self _saveTransfers];

	count = [self _numberOfWorkingTransfersOfClass:[transfer class] connection:[destination connection]];
	
	if(count == 1)
		[self showWindow:self];
	
	if(count > 1 && [[WCSettings settings] boolForKey:WCQueueTransfers])
		[transfer setState:WCTransferLocallyQueued];
	else
		[self _requestTransfer:transfer];
	
	[_transfersTableView reloadData];
	
	if(resourceForks > 0 && [[WCSettings settings] boolForKey:WCCheckForResourceForks]) {
		if(resourceForks == 1) {
			error = [WCError errorWithDomain:WCWiredClientErrorDomain
										code:WCWiredClientTransferWithResourceFork
									argument:resourceForkPath];
		} else {
			error = [WCError errorWithDomain:WCWiredClientErrorDomain
										code:WCWiredClientTransferWithResourceFork
									argument:[NSNumber numberWithInt:resourceForks]];
		}
		
		[self _presentError:error forConnection:[destination connection] transfer:NULL];
	}
	
	return YES;
}



#pragma mark -

- (void)_requestNextTransferForConnection:(WCServerConnection *)connection {
	WCTransfer		*transfer = NULL;
	NSUInteger		downloads, uploads;
	
	if(![[WCSettings settings] boolForKey:WCQueueTransfers]) {
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

	[_errorQueue dismissErrorWithIdentifier:[transfer identifier]];
	
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

	[self _validate];
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
	WCFile			*directory;
	NSUInteger		i, count;
	
	directories = [transfer uncreatedDirectories];
	count = [directories count];
	
	if(count > 0 && ![transfer isTerminating]) {
		[transfer setState:WCTransferCreatingDirectories];
		
		[self _validate];
	}
	
	for(i = 0; i < count; i++) {
		directory = [directories objectAtIndex:i];
		
		if([transfer isKindOfClass:[WCDownloadTransfer class]]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:[directory transferLocalPath]];
			
			[transfer addCreatedDirectory:directory];
		} else {
			message = [WIP7Message messageWithName:@"wired.transfer.upload_directory" spec:WCP7Spec];
			[message setString:[directory path] forName:@"wired.file.path"];
			[[transfer connection] sendMessage:message fromObserver:self selector:@selector(wiredTransferUploadDirectoryReply:)];
			
			[transfer addCreatedDirectory:directory];
		}
	}
	
	[transfer removeAllUncreatedDirectories];
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
	
	[[WCSettings settings] setObject:[NSKeyedArchiver archivedDataWithRootObject:transfers] forKey:WCTransferList];
}



- (void)_finishTransfer:(WCTransfer *)transfer {
	NSString			*path, *newPath;
	NSDictionary		*dictionary;
	WCFile				*file;
	WCTransferState		state;
	BOOL				download, next = YES;
	
	[transfer retain];
	
	file		= [[transfer firstUntransferredFile] retain];
	path		= [file transferLocalPath];
	download	= [transfer isKindOfClass:[WCDownloadTransfer class]];
	
	if((download && [file dataTransferred] + [file rsrcTransferred] >= [file dataSize] + [file rsrcSize]) ||
	   (!download && [file dataTransferred] + [file rsrcTransferred] >= [file uploadDataSize] + [file uploadRsrcSize])) {
		if([transfer isKindOfClass:[WCDownloadTransfer class]]) {
			newPath = [path stringByDeletingPathExtension];
			
			[[NSFileManager defaultManager] removeExtendedAttributeForName:WCTransfersFileExtendedAttributeName atPath:path error:NULL];
			[[NSFileManager defaultManager] movePath:path toPath:newPath handler:NULL];
			
			[transfer setLocalPath:newPath];
			path = newPath;
			
			if([file isExecutable]) {
				dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0755] forKey:NSFilePosixPermissions];
				
				[[NSFileManager defaultManager] changeFileAttributes:dictionary atPath:path];
			}
		}
		
		if(file) {
			[transfer addTransferredFile:file];
			[transfer removeUntransferredFile:file];
		}
		
		if([transfer numberOfUntransferredFiles] == 0) {
			[[transfer transferConnection] disconnect];
			[transfer setTransferConnection:NULL];
			[transfer setState:WCTransferFinished];
			[[transfer progressIndicator] setDoubleValue:1.0];
			
			if([[WCSettings settings] boolForKey:WCRemoveTransfers])
				[self _removeTransfer:transfer];

			[_transfersTableView reloadData];

			[self _validate];

			[[transfer connection] triggerEvent:WCEventsTransferFinished info1:transfer];
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
	[transfer release];
}



- (void)_finishTransfer:(WCTransfer *)transfer withError:(WCError *)error {
	[self _presentError:error forConnection:[transfer connection] transfer:transfer];
	[self _finishTransfer:transfer];
}



- (void)_removeTransfer:(WCTransfer *)transfer {
	[[transfer progressIndicator] removeFromSuperview];

	[_transfers removeObject:transfer];

	[self _saveTransfers];
}



#pragma mark -

- (WCTransferConnection *)_transferConnectionForTransfer:(WCTransfer *)transfer {
	WCTransferConnection		*connection;
	
	connection = [WCTransferConnection connectionWithTransfer:transfer];
	[connection setURL:[[transfer connection] URL]];
	[connection setBookmark:[[transfer connection] bookmark]];
	
	return connection;
}



- (BOOL)_sendDownloadFileMessageOnConnection:(WCTransferConnection *)connection forFile:(WCFile *)file error:(WCError **)error {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.transfer.download_file" spec:WCP7Spec];
	[message setString:[file path] forName:@"wired.file.path"];
	[message setUInt64:[file dataTransferred] forName:@"wired.transfer.data_offset"];
	[message setUInt64:[file rsrcTransferred] forName:@"wired.transfer.rsrc_offset"];

	return [connection writeMessage:message timeout:30.0 error:error];
}



- (BOOL)_sendUploadFileMessageOnConnection:(WCTransferConnection *)connection forFile:(WCFile *)file error:(WCError **)error {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.transfer.upload_file" spec:WCP7Spec];
	[message setString:[file path] forName:@"wired.file.path"];
	[message setUInt64:[file uploadDataSize] forName:@"wired.transfer.data_size"];
	[message setUInt64:[file uploadRsrcSize] forName:@"wired.transfer.rsrc_size"];
	
	if([[[NSFileManager defaultManager] fileAttributesAtPath:[file transferLocalPath] traverseLink:YES] filePosixPermissions] & 0111)
		[message setBool:YES forName:@"wired.file.executable"];
	
	return [connection writeMessage:message timeout:30.0 error:error];
}



- (BOOL)_sendUploadMessageOnConnection:(WCTransferConnection *)connection forFile:(WCFile *)file dataLength:(WIFileOffset)dataLength rsrcLength:(WIFileOffset)rsrcLength error:(WCError **)error {
	NSData			*finderInfo;
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.transfer.upload" spec:WCP7Spec];
	[message setString:[file path] forName:@"wired.file.path"];
	[message setUInt64:dataLength forName:@"wired.transfer.data"];
	[message setUInt64:rsrcLength forName:@"wired.transfer.rsrc"];
	
	finderInfo = [[NSFileManager defaultManager] finderInfoAtPath:[file transferLocalPath]];
	
	[message setData:finderInfo ? finderInfo : [NSData data] forName:@"wired.transfer.finderinfo"];
	
	return [connection writeMessage:message timeout:30.0 error:error];
}



- (BOOL)_createRemainingDirectoriesOnConnection:(WCTransferConnection *)connection forTransfer:(WCTransfer *)transfer error:(WCError **)error {
	NSArray			*directories;
	WIP7Message		*message;
	WCFile			*directory;
	NSUInteger		i, count;
	
	directories = [transfer uncreatedDirectories];
	count = [directories count];
	
	if(count > 0 && ![transfer isTerminating]) {
		[transfer setState:WCTransferCreatingDirectories];
		
		[self performSelectorOnMainThread:@selector(_validate)];
	}
	
	for(i = 0; i < count; i++) {
		directory = [directories objectAtIndex:i];
		
		if([transfer isKindOfClass:[WCDownloadTransfer class]]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:[[directories objectAtIndex:i] transferLocalPath]];
			
			[transfer addCreatedDirectory:directory];
			[transfer removeUncreatedDirectory:directory];
			
			count--;
			i--;
		} else {
			message = [WIP7Message messageWithName:@"wired.transfer.upload_directory" spec:WCP7Spec];
			[message setString:[directory path] forName:@"wired.file.path"];

			if(![connection writeMessage:message timeout:30.0 error:error])
				return NO;
			
			message = [self _runConnection:connection
							   forTransfer:transfer
				 untilReceivingMessageName:@"wired.okay"
									 error:error];
			
			if(!message)
				return NO;
			
			[transfer addCreatedDirectory:directory];
			[transfer removeUncreatedDirectory:directory];
			
			count--;
			i--;
		}
	}
	
	[transfer removeAllUncreatedDirectories];
	
	return YES;
}



- (BOOL)_connectConnection:(WCTransferConnection *)connection forTransfer:(WCTransfer *)transfer error:(WCError **)error {
	WIP7Message		*message;
	
	if(![connection connectWithTimeout:30.0 error:error])
		return NO;
	
	if(![connection writeMessage:[connection clientInfoMessage] timeout:30.0 error:error] ||
	   ![connection writeMessage:[connection setNickMessage] timeout:30.0 error:error] ||
	   ![connection writeMessage:[connection setStatusMessage] timeout:30.0 error:error] ||
	   ![connection writeMessage:[connection setIconMessage] timeout:30.0 error:error] ||
	   ![connection writeMessage:[connection loginMessage] timeout:30.0 error:error])
		return NO;
	
	message = [self _runConnection:connection
					   forTransfer:transfer
		 untilReceivingMessageName:@"wired.account.privileges"
							 error:error];
	
	if(!message)
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
		
		if([name isEqualToString:messageName]) {
			*error = NULL;
			
			return message;
		}

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
	NSAutoreleasePool			*pool;
	NSProgressIndicator			*progressIndicator;
	NSString					*dataPath, *rsrcPath;
	NSFileHandle				*dataFileHandle, *rsrcFileHandle;
	NSData						*finderInfo;
	WIP7Socket					*socket;
	WIP7Message					*message;
	WCTransferConnection		*connection;
	WCFile						*file;
	WCError						*error;
	void						*buffer;
	NSTimeInterval				time, speedTime, statsTime;
	NSUInteger					i, speedBytes, statsBytes;
	NSInteger					readBytes;
	WIP7UInt64					dataLength, rsrcLength;
	double						percent, maxSpeed;
	int							dataFD, rsrcFD, writtenBytes;
	BOOL						data;
	
	error = NULL;
	connection = [transfer transferConnection];
	
	if(!connection) {
		connection = [self _transferConnectionForTransfer:transfer];
		
		if(![self _connectConnection:connection forTransfer:transfer error:&error]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
			
			[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
								   withObject:transfer
								   withObject:error];

			return;
		}
		
		[transfer setTransferConnection:connection];
	}
	
	file				= [transfer firstUntransferredFile];
	dataPath			= [file transferLocalPath];
	rsrcPath			= [NSFileManager resourceForkPathForPath:dataPath];
	speedBytes			= 0;
	statsBytes			= 0;
	maxSpeed			= 0;
	i					= 0;
	socket				= [connection socket];
	speedTime			= _WCTransfersTimeInterval();
	statsTime			= speedTime;
	progressIndicator	= [transfer progressIndicator];
	data				= YES;
	
	[[socket socket] setInteractive:NO];
	
	if(![self _createRemainingDirectoriesOnConnection:connection forTransfer:transfer error:&error]) {
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}
		
		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		
		return;
	}
	
	if(![self _sendDownloadFileMessageOnConnection:connection forFile:file error:&error]) {
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}
		
		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		
		return;
	}
	
	message = [self _runConnection:connection
					   forTransfer:transfer
		 untilReceivingMessageName:@"wired.transfer.download"
							 error:&error];
	
	if(!message) {
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}
		
		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		
		return;
	}
	
	[message getUInt64:&dataLength forName:@"wired.transfer.data"];
	[message getUInt64:&rsrcLength forName:@"wired.transfer.rsrc"];
	
	if((![[NSFileManager defaultManager] fileExistsAtPath:dataPath] &&
		![[NSFileManager defaultManager] createFileAtPath:dataPath]) ||
	   (![[NSFileManager defaultManager] fileExistsAtPath:rsrcPath] &&
		![[NSFileManager defaultManager] createFileAtPath:rsrcPath])) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientCreateFailed argument:dataPath];
		
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}

		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		   
		return;
	}
	
	finderInfo = [message dataForName:@"wired.transfer.finderinfo"];
	
	if([finderInfo length] > 0)
		[[NSFileManager defaultManager] setFinderInfo:finderInfo atPath:dataPath];
	
	dataFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:dataPath];
	rsrcFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:rsrcPath];
	
	if(!dataFileHandle || !rsrcFileHandle) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:dataPath];
		
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}

		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		
		return;
	}
	
	[dataFileHandle seekToFileOffset:[file dataTransferred]];
	[rsrcFileHandle seekToFileOffset:[file rsrcTransferred]];
	
	if(![transfer isTerminating]) {
		[transfer setState:WCTransferRunning];
		
		[self performSelectorOnMainThread:@selector(_validate)];
	}
	
	dataFD = [dataFileHandle fileDescriptor];
	rsrcFD = [rsrcFileHandle fileDescriptor];
	
	wi_speed_calculator_add_bytes_at_time(transfer->_speedCalculator, 0, speedTime);
	
	pool = [[NSAutoreleasePool alloc] init];
	
	while(![transfer isTerminating]) {
		if(data && dataLength == 0)
			data = NO;
		
		if(!data && rsrcLength == 0)
			break;
		
		readBytes = [socket readOOBData:&buffer timeout:30.0 error:&error];
		
		if(readBytes <= 0) {
			[transfer setState:WCTransferDisconnecting];

			break;
		}
		
		if((data && dataLength < (NSUInteger) readBytes) || (!data && rsrcLength < (NSUInteger) readBytes)) {
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];
			
			break;
		}
		
		writtenBytes = write(data ? dataFD : rsrcFD, buffer, readBytes);
		
		if(writtenBytes <= 0) {
			if(writtenBytes < 0)
				error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];
			
			break;
		}
		
		if(data) {
			dataLength					-= readBytes;
			transfer->_dataTransferred	+= readBytes;
			file->_dataTransferred		+= readBytes;
		} else {
			rsrcLength					-= readBytes;
			transfer->_rsrcTransferred	+= readBytes;
			file->_rsrcTransferred		+= readBytes;
		}
			
		transfer->_actualTransferred	+= readBytes;
		statsBytes						+= readBytes;
		speedBytes						+= readBytes;
		percent							= (transfer->_dataTransferred + transfer->_rsrcTransferred) / (double) transfer->_size;
		time							= _WCTransfersTimeInterval();
		
		if(percent == 1.00 || percent - [progressIndicator doubleValue] >= 0.001)
			[progressIndicator setDoubleValue:percent];
	
		if(transfer->_speed == 0.0 || time - speedTime > 0.33) {
			wi_speed_calculator_add_bytes_at_time(transfer->_speedCalculator, speedBytes, speedTime);

			transfer->_speed = wi_speed_calculator_speed(transfer->_speedCalculator);
			
			if(transfer->_speed > maxSpeed)
				maxSpeed = transfer->_speed;
			
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
	
	wi_speed_calculator_add_bytes_at_time(transfer->_speedCalculator, speedBytes, speedTime);
	
	transfer->_speed = wi_speed_calculator_speed(transfer->_speedCalculator);
	
	if(statsBytes > 0)
		[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsDownloaded];

	if([[WCStats stats] unsignedIntForKey:WCStatsMaxDownloadSpeed] < maxSpeed)
		[[WCStats stats] setUnsignedInt:maxSpeed forKey:WCStatsMaxDownloadSpeed];
	
	[transfer signalTerminated];
	
	if(error) {
		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
	} else {
		[self performSelectorOnMainThread:@selector(_finishTransfer:) withObject:transfer];
	}
	
	[pool release];
}



- (void)_runUpload:(WCTransfer *)transfer {
	NSAutoreleasePool			*pool;
	NSProgressIndicator			*progressIndicator;
	NSString					*dataPath, *rsrcPath;
	NSFileHandle				*dataFileHandle, *rsrcFileHandle;
	WIP7Socket					*socket;
	WIP7Message					*message;
	WCTransferConnection		*connection;
	WCFile						*file;
	WCError						*error;
	char						buffer[8192];
	NSTimeInterval				time, speedTime, statsTime;
	NSUInteger					i, sendBytes, speedBytes, statsBytes;
	WIP7UInt64					dataLength, rsrcLength;
	WIP7UInt64					dataOffset, rsrcOffset;
	double						percent, maxSpeed;
	ssize_t						readBytes;
	int							dataFD, rsrcFD;
	BOOL						data;
	
	error = NULL;
	connection = [transfer transferConnection];
	
	if(!connection) {
		connection = [self _transferConnectionForTransfer:transfer];
		
		if(![self _connectConnection:connection forTransfer:transfer error:&error]) {
			if(![transfer isTerminating]) {
				[transfer setState:WCTransferStopping];
				[transfer signalTerminated];
			}
			
			[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
								   withObject:transfer
								   withObject:error];
			
			return;
		}
		
		[transfer setTransferConnection:connection];
	}
	
	file				= [transfer firstUntransferredFile];
	dataPath			= [file transferLocalPath];
	rsrcPath			= [NSFileManager resourceForkPathForPath:dataPath];
	speedBytes			= 0;
	statsBytes			= 0;
	maxSpeed			= 0;
	i					= 0;
	socket				= [connection socket];
	speedTime			= _WCTransfersTimeInterval();
	statsTime			= _WCTransfersTimeInterval();
	progressIndicator	= [transfer progressIndicator];
	data				= YES;
	
	[[socket socket] setInteractive:NO];
	
	if(![self _createRemainingDirectoriesOnConnection:connection forTransfer:transfer error:&error]) {
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}

		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		
		return;
	}

	if(![self _sendUploadFileMessageOnConnection:connection forFile:file error:&error]) {
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}
		
		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		
		return;
	}
	
	message = [self _runConnection:connection
					   forTransfer:transfer
		 untilReceivingMessageName:@"wired.transfer.upload_ready"
							 error:&error];
	
	if(!message) {
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}
		
		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		
		return;
	}
	
	[message getUInt64:&dataOffset forName:@"wired.transfer.data_offset"];
	[message getUInt64:&rsrcOffset forName:@"wired.transfer.rsrc_offset"];
	
	dataLength = [file uploadDataSize] - dataOffset;
	rsrcLength = [file uploadRsrcSize] - rsrcOffset;
	
	if(![self _sendUploadMessageOnConnection:connection forFile:file dataLength:dataLength rsrcLength:rsrcLength error:&error]) {
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}
		
		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		
		return;
	}
	
	dataFileHandle = [NSFileHandle fileHandleForReadingAtPath:dataPath];
	rsrcFileHandle = [NSFileHandle fileHandleForReadingAtPath:rsrcPath];
	
	if(!dataFileHandle || !rsrcFileHandle) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:dataPath];
		
		if(![transfer isTerminating]) {
			[transfer setState:WCTransferStopping];
			[transfer signalTerminated];
		}
		
		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
		
		return;
	}

	[dataFileHandle seekToFileOffset:dataOffset];
	[rsrcFileHandle seekToFileOffset:rsrcOffset];
	
	if(![transfer isTerminating]) {
		[transfer setState:WCTransferRunning];
		
		[self performSelectorOnMainThread:@selector(_validate)];
	}
	
	dataFD = [dataFileHandle fileDescriptor];
	rsrcFD = [rsrcFileHandle fileDescriptor];
	
	wi_speed_calculator_add_bytes_at_time(transfer->_speedCalculator, 0, speedTime);

	pool = [[NSAutoreleasePool alloc] init];

	while(![transfer isTerminating]) {
		if(data && dataLength == 0)
			data = NO;
		
		if(!data && rsrcLength == 0)
			break;
		
		readBytes = read(data ? dataFD : rsrcFD, buffer, sizeof(buffer));

		if(readBytes <= 0) {
			if(readBytes < 0)
				error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];

			if(![transfer isTerminating])
				[transfer setState:WCTransferStopping];
			
			break;
		}
		
		if(data)
			sendBytes = (dataLength < (NSUInteger) readBytes) ? dataLength : (NSUInteger) readBytes;
		else
			sendBytes = (rsrcLength < (NSUInteger) readBytes) ? rsrcLength : (NSUInteger) readBytes;
		
		if(![socket writeOOBData:buffer length:sendBytes timeout:30.0 error:&error]) {
			[transfer setState:WCTransferDisconnecting];

			break;
		}

		if(data) {
			dataLength					-= sendBytes;
			transfer->_dataTransferred	+= sendBytes;
			file->_dataTransferred		+= sendBytes;
		} else {
			rsrcLength					-= sendBytes;
			transfer->_rsrcTransferred	+= sendBytes;
			file->_rsrcTransferred		+= sendBytes;
		}
		
		transfer->_actualTransferred	+= readBytes;
		speedBytes						+= sendBytes;
		statsBytes						+= sendBytes;
		percent							= (transfer->_dataTransferred + transfer->_rsrcTransferred) / (double) transfer->_size;
		time							= _WCTransfersTimeInterval();
		
		if(percent == 1.00 || percent - [progressIndicator doubleValue] >= 0.001)
			[progressIndicator setDoubleValue:percent];
		
		if(transfer->_speed == 0.0 || time - speedTime > 0.33) {
			wi_speed_calculator_add_bytes_at_time(transfer->_speedCalculator, speedBytes, speedTime);
			
			transfer->_speed = wi_speed_calculator_speed(transfer->_speedCalculator);
			
			if(transfer->_speed > maxSpeed)
				maxSpeed = transfer->_speed;

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
	
	wi_speed_calculator_add_bytes_at_time(transfer->_speedCalculator, speedBytes, speedTime);
	
	transfer->_speed = wi_speed_calculator_speed(transfer->_speedCalculator);
	
	if(statsBytes > 0)
		[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsDownloaded];

	if([[WCStats stats] unsignedIntForKey:WCStatsMaxDownloadSpeed] < maxSpeed)
		[[WCStats stats] setUnsignedInt:maxSpeed forKey:WCStatsMaxDownloadSpeed];
	
	[transfer signalTerminated];
	
	if(error) {
		[self performSelectorOnMainThread:@selector(_finishTransfer:withError:)
							   withObject:transfer
							   withObject:error];
	} else {
		[self performSelectorOnMainThread:@selector(_finishTransfer:) withObject:transfer];
	}
	
	[pool release];
}

@end


@implementation WCTransfers

+ (id)transfers {
	static WCTransfers   *sharedTransfers;
	
	if(!sharedTransfers)
		sharedTransfers = [[self alloc] init];
	
	return sharedTransfers;
}



#pragma mark -

- (id)init {
	self = [super initWithWindowNibName:@"Transfers"];

	_folderImage			= [[NSImage imageNamed:@"Folder"] retain];

	_quickLookTransfers		= [[NSMutableArray alloc] init];
	_quickLookPanelClass	= NSClassFromString(@"QLPreviewPanel");

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
	[_transfers release];
	[_quickLookTransfers release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSEnumerator	*enumerator;
	NSToolbar		*toolbar;
	NSData			*data;
	WCTransfer		*transfer;
	
	_errorQueue = [[WCErrorQueue alloc] initWithWindow:[self window]];
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Transfers"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];
	
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Transfers"];

	[_transfersTableView setTarget:self];
	[_transfersTableView setSpaceAction:@selector(quickLook:)];
	[_transfersTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:NSStringPboardType, WCTransferPboardType, NULL]];

    data = [[WCSettings settings] objectForKey:WCTransferList];

    if(data)
        _transfers = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
	
	if(!_transfers)
		_transfers = [[NSMutableArray alloc] init];
	
	enumerator = [_transfers objectEnumerator];
	
	while((transfer = [enumerator nextObject])) {
		if([transfer state] == WCTransferDisconnecting)
			[transfer setState:WCTransferDisconnected];
	}
	
	[_transfersTableView reloadData];

	[self _themeDidChange];
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"Start"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Start", @"Start transfer toolbar item")
												content:_startButton
												 target:self
												 action:@selector(start:)];
	}
	else if([identifier isEqualToString:@"Pause"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Pause", @"Pause transfer toolbar item")
												content:_pauseButton
												 target:self
												 action:@selector(pause:)];
	}
	else if([identifier isEqualToString:@"Stop"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Stop", @"Stop transfer toolbar item")
												content:_stopButton
												 target:self
												 action:@selector(stop:)];
	}
	else if([identifier isEqualToString:@"Remove"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Remove", @"Remove transfer toolbar item")
												content:_removeButton
												 target:self
												 action:@selector(remove:)];
	}
	else if([identifier isEqualToString:@"Clear"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Clear", @"Clear transfers toolbar item")
												content:_clearButton
												 target:self
												 action:@selector(clear:)];
	}
	else if([identifier isEqualToString:@"Connect"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Connect", @"Connect transfer toolbar item")
												content:_connectButton
												 target:self
												 action:@selector(connect:)];
	}
	else if([identifier isEqualToString:@"QuickLook"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Quick Look", @"Quick look transfers toolbar item")
												content:_quickLookButton
												 target:self
												 action:@selector(quickLook:)];
	}
	else if([identifier isEqualToString:@"RevealInFinder"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reveal In Finder", @"Reveal transfer in Finder toolbar item")
												content:_revealInFinderButton
												 target:self
												 action:@selector(revealInFinder:)];
	}
	else if([identifier isEqualToString:@"RevealInFiles"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reveal In Files", @"Reveal transfer in files toolbar item")
												content:_revealInFilesButton
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
		@"QuickLook",
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
		@"QuickLook",
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
	NSData				*data;
	NSString			*path;
	WCTransfer			*transfer;
	WCFile				*file;

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer isWorking]) {
			[transfer setState:WCTransferDisconnecting];
			
			if([transfer waitUntilTerminatedBeforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]])
				[transfer setState:WCTransferDisconnected];
		}
	}

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if(![transfer isFolder] && [transfer isStopped] && [transfer state] != WCTransferDisconnected) {
			file = [transfer firstUntransferredFile];
			
			if(file) {
				path = [file transferLocalPath];
				data = [NSKeyedArchiver archivedDataWithRootObject:transfer];
				
				[[NSFileManager defaultManager] setExtendedAttribute:data
															 forName:WCTransfersFileExtendedAttributeName
															  atPath:path
															   error:NULL];
			}
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

	if([[message name] isEqualToString:@"wired.file.file_list"]) {
		file = [WCFile fileWithMessage:message connection:[transfer connection]];
		
		if([transfer isKindOfClass:[WCDownloadTransfer class]]) {
			rootPath = [[transfer remotePath] stringByDeletingLastPathComponent];
			localPath = [[transfer destinationPath] stringByAppendingPathComponent:
				[[file path] substringFromIndex:[rootPath length]]];
			
			[file setTransferLocalPath:localPath];
			
			if([file type] == WCFileFile) {
				if(![transfer containsTransferredFile:file] && ![transfer containsUntransferredFile:file]) {
					if([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
						[transfer setDataTransferred:[transfer dataTransferred] + [file dataSize]];
						[transfer setRsrcTransferred:[transfer rsrcTransferred] + [file rsrcSize]];
					} else {
						[transfer setSize:[transfer size] + [file dataSize] + [file rsrcSize]];
						
						if(![localPath hasSuffix:WCTransfersFileExtension])
							localPath = [localPath stringByAppendingPathExtension:WCTransfersFileExtension];
						
						[file setDataTransferred:[[NSFileManager defaultManager] fileSizeAtPath:localPath]];
						
						if([[file connection] supportsResourceForks])
							[file setRsrcTransferred:[[NSFileManager defaultManager] resourceForkSizeAtPath:localPath]];
						
						[file setTransferLocalPath:localPath];
						
						[transfer addUntransferredFile:file];
						[transfer setDataTransferred:[transfer dataTransferred] + [file dataTransferred]];
						[transfer setRsrcTransferred:[transfer rsrcTransferred] + [file rsrcTransferred]];
					}
				}
			} else {
				if(![transfer containsUncreatedDirectory:file] && ![transfer containsCreatedDirectory:file])
					[transfer addUncreatedDirectory:file];
			}
		} else {
			if([file type] == WCFileFile) {
				if([transfer containsUntransferredFile:file])
					[transfer removeUntransferredFile:file];
				
				if(![transfer containsTransferredFile:file]) {
					[transfer setDataTransferred:[transfer dataTransferred] + [file dataSize] + [file rsrcSize]];
					[transfer removeUntransferredFile:file];
				}
			} else {
				if([transfer containsUncreatedDirectory:file])
					[transfer removeUncreatedDirectory:file];
				
				if(![transfer containsCreatedDirectory:file])
					[transfer addCreatedDirectory:file];
			}
		}
		
		if([[transfer uncreatedDirectories] count] + [[transfer createdDirectories] count] % 10 == 0 ||
		   [transfer numberOfUntransferredFiles] + [transfer numberOfTransferredFiles] % 10 == 0) {
			rect = [_transfersTableView frameOfCellAtColumn:1 row:[_transfers indexOfObject:transfer]];

			[_transfersTableView setNeedsDisplayInRect:rect];
		}
	}
	else if([[message name] isEqualToString:@"wired.file.file_list.done"]) {
		if([transfer numberOfUntransferredFiles] > 0) {
			[self _startTransfer:transfer first:YES];
		} else {
			[self _createRemainingDirectoriesForTransfer:transfer];
			[self _finishTransfer:transfer];
		}
		
		[[transfer connection] removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
		
		[[transfer connection] removeObserver:self message:message];
	}
}



- (void)wiredTransferUploadDirectoryReply:(WIP7Message *)message {
	WCServerConnection		*connection;
	WCError					*error;
	
	connection = [message contextInfo];
	
	if([[message name] isEqualToString:@"wired.okay"]) {
		[connection removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		error = [WCError errorWithWiredMessage:message];
		
		if([error code] != WCWiredProtocolFileExists)
			[_errorQueue showError:error];
		
		[connection removeObserver:self message:message];
	}
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;
	
	selector = [item action];
	
	if(selector == @selector(deleteDocument:))
		return [self _validateRemove];
	else if(selector == @selector(quickLook:))
		return [self _validateQuickLook];
	
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
	NSRect			rect;
	NSUInteger		i, count;
	
	count = [_transfers count];
	
	for(i = 0; i < count; i++) {
		if([[_transfers objectAtIndex:i] isWorking]) {
			rect = [_transfersTableView frameOfCellAtColumn:1 row:i];

			[_transfersTableView setNeedsDisplayInRect:rect];
		}
	}
}



#pragma mark -

- (NSString *)deleteDocumentMenuItemTitle {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	if(transfer)
		return [NSSWF:NSLS(@"Remove \u201c%@\u201d", @"Delete menu item (transfer"), [transfer name]];
	
	return NSLS(@"Delete", @"Delete menu item");
}



- (NSString *)quickLookMenuItemTitle {
	WCTransfer		*transfer;
	
	transfer = [self _selectedTransfer];
	
	if(transfer)
		return [NSSWF:NSLS(@"Quick Look \u201c%@\u201d", @"Quick Look menu item (transfer"), [transfer name]];
	
	return NSLS(@"Quick Look", @"Quick Look menu item");
}



#pragma mark -

- (BOOL)addTransferAtPath:(NSString *)path {
	NSData			*data;
	WCTransfer		*transfer, *existingTransfer;
	NSUInteger		index;
	
	[self showWindow:self];
	
	data = [[NSFileManager defaultManager] extendedAttributeForName:WCTransfersFileExtendedAttributeName atPath:path error:NULL];
	
	if(!data)
		return NO;
	
	transfer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
	if(!transfer || ![transfer isKindOfClass:[WCTransfer class]])
		return NO;
	
	existingTransfer = [self _unfinishedTransferWithPath:[[transfer firstUntransferredFile] path]];
	
	if(existingTransfer) {
		index = [_transfers indexOfObject:existingTransfer];
	} else {
		[transfer setState:WCTransferDisconnected];
		
		[_transfers addObject:transfer];
		[_transfersTableView reloadData];
		
		index = [_transfers count] - 1;
	}
	
	if(index != NSNotFound)
		[_transfersTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
	
	return YES;
}



- (BOOL)downloadFile:(WCFile *)file {
	return [self _downloadFile:file toFolder:[[[WCSettings settings] objectForKey:WCDownloadFolder] stringByStandardizingPath]];
}



- (BOOL)downloadFile:(WCFile *)file toFolder:(NSString *)destination {
	return [self _downloadFile:file toFolder:destination];
}



- (BOOL)uploadPath:(NSString *)path toFolder:(WCFile *)destination {
	return [self _uploadPath:path toFolder:destination];
}



#pragma mark -

- (IBAction)deleteDocument:(id)sender {
	[self remove:sender];
}



- (IBAction)start:(id)sender {
	WCTransfer		*transfer;
	
	if(![self _validateStart])
		return;
	
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
	
	if(![self _validatePause])
		return;
	
	transfer = [self _selectedTransfer];
	
	if([transfer state] == WCTransferRunning)
		[transfer setState:WCTransferPausing];
	
	[_transfersTableView setNeedsDisplay:YES];

	[self _validate];
}



- (IBAction)stop:(id)sender {
	if(![self _validateStop])
		return;
	
	[[self _selectedTransfer] setState:WCTransferStopping];

	[_transfersTableView setNeedsDisplay:YES];

	[self _validate];
}



- (IBAction)remove:(id)sender {
	WCTransfer		*transfer;
	
	if(![self _validateRemove])
		return;

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
	
	if(![self _validateClear])
		return;

	while((transfer = [self _transferWithState:WCTransferFinished]))
		[self _removeTransfer:transfer];

	[_transfersTableView setNeedsDisplay:YES];
	[_transfersTableView reloadData];
	
	[self _validate];
}



- (IBAction)quickLook:(id)sender {
	WCTransfer		*transfer;
	id				quickLookPanel;
	
	if(![self _validateQuickLook])
		return;
	
	transfer = [self _selectedTransfer];
	
	[_quickLookTransfers setArray:[NSArray arrayWithObject:transfer]];
	
	quickLookPanel = [_quickLookPanelClass performSelector:@selector(sharedPreviewPanel)];
	
	if([quickLookPanel isVisible])
		[quickLookPanel orderOut:self];
	else
		[quickLookPanel makeKeyAndOrderFront:self];

	if(NSAppKitVersionNumber >= 1038.0) {
		if([quickLookPanel respondsToSelector:@selector(reloadData)])
			[quickLookPanel performSelector:@selector(reloadData)];
	} else {
		if([quickLookPanel respondsToSelector:@selector(setURLs:)]) {
			[quickLookPanel performSelector:@selector(setURLs:)
								 withObject:[NSArray arrayWithObject:[[_quickLookTransfers objectAtIndex:0] previewItemURL]]];
		}
	}
}



- (IBAction)connect:(id)sender {
	WCConnect		*connect;
	WCTransfer		*transfer;
	
	if(![self _validateConnect])
		return;
	
	transfer = [self _selectedTransfer];
	
	connect = [WCConnect connectWithURL:[transfer URL] bookmark:[transfer bookmark]];
	[connect showWindow:self];
	[connect connect:self];
}



- (IBAction)revealInFinder:(id)sender {
	NSString		*path;
	WCTransfer		*transfer;
	
	if(![self _validateRevealInFinder])
		return;
	
	transfer = [self _selectedTransfer];
	
	if([transfer isFolder])
		path = [[transfer destinationPath] stringByAppendingPathComponent:[transfer name]];
	else
		path = [transfer localPath];
	
	[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:NULL];
}



- (IBAction)revealInFiles:(id)sender {
	WCTransfer		*transfer;
	NSString		*path;
	
	if(![self _validateRevealInFiles])
		return;
	
	transfer = [self _selectedTransfer];
	path = [transfer remotePath];
	
	[WCFiles filesWithConnection:[transfer connection]
							file:[WCFile fileWithDirectory:[path stringByDeletingLastPathComponent] connection:[transfer connection]]
					  selectFile:[WCFile fileWithDirectory:path connection:[transfer connection]]];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_transfers count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	WCTransfer		*transfer;

	transfer = [_transfers objectAtIndex:row];

	if(tableColumn == _iconTableColumn) {
		return [transfer icon];
	}
	else if(tableColumn == _infoTableColumn) {
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[transfer name],				WCTransferCellNameKey,
			[transfer status],				WCTransferCellStatusKey,
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



#pragma mark -

- (BOOL)acceptsPreviewPanelControl:(id /*QLPreviewPanel **/)panel {
    return YES;
}



- (void)beginPreviewPanelControl:(id /*QLPreviewPanel **/)panel {
    [panel setDelegate:self];
    [panel setDataSource:self];
}



- (void)endPreviewPanelControl:(id /*QLPreviewPanel **/) panel {
}



- (NSInteger)numberOfPreviewItemsInPreviewPanel:(id /*QLPreviewPanel **/)panel {
	return [_quickLookTransfers count];
}



- (id /*id <QLPreviewItem>*/)previewPanel:(id /*QLPreviewPanel **/)panel previewItemAtIndex:(NSInteger)index {
	return [_quickLookTransfers objectAtIndex:index];
}



- (NSRect)previewPanel:(id /*QLPreviewPanel **/)panel sourceFrameOnScreenForPreviewItem:(id /*id <QLPreviewItem>*/)item {
	NSRect			frame;
	NSUInteger		index;
	
	index = [_transfers indexOfObject:item];
	
	if(index != NSNotFound) {
		frame				= [_transfersTableView convertRect:[_transfersTableView frameOfCellAtColumn:0 row:index] toView:NULL];
		frame.origin		= [[self window] convertBaseToScreen:frame.origin];

		return NSMakeRect(frame.origin.x, frame.origin.y, frame.size.height, frame.size.height);
	}

	return NSZeroRect;
}

@end
