/* $Id$ */

/*
 *  Copyright (c) 2006-2007 Axel Andersson
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
#import "WCFilesController.h"
#import "WCFileInfo.h"
#import "WCPreferences.h"
#import "WCServerConnection.h"
#import "WCTransfers.h"

@implementation WCFilesController

- (id)init {
	self = [super init];
	
	_files = [[NSMutableArray alloc] initWithCapacity:1000];
	
	return self;
}



- (void)dealloc {
	[_files release];
	[_dateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (void)awakeFromNib {
	[_filesTableView setAllowsUserCustomization:YES];
	[_filesTableView setDefaultHighlightedTableColumnIdentifier:@"Name"];
	[_filesTableView setDefaultTableColumnIdentifiers:
		[NSArray arrayWithObjects:@"Name", @"Size", NULL]];
	[_filesTableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	[_filesTableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];

	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
}



#pragma mark -

- (void)themeDidChange:(NSDictionary *)theme {
	[_filesTableView setUsesAlternatingRowBackgroundColors:[theme boolForKey:WCThemesFileListAlternateRows]];
}



- (void)updateStatus {
	[self updateStatusWithFree:-1];
}



- (void)updateStatusWithFree:(WIFileOffset)free {
	NSEnumerator		*enumerator;
	WCFile				*file;
	WIFileOffset		size = 0;

	enumerator = [_files objectEnumerator];

	while((file = [enumerator nextObject]))
		if([file type] == WCFileFile)
			size += [file size];

	if(free == (WIFileOffset) -1) {
		[_statusTextField setStringValue:[NSSWF:
			NSLS(@"%lu %@, %@ total", @"Search info (items, 'item(s)', total)"),
			[_files count],
			[_files count] == 1
				? NSLS(@"item", @"Item singular")
				: NSLS(@"items", @"Item plural"),
			[NSString humanReadableStringForSizeInBytes:size]]];
	} else {
		[_statusTextField setStringValue:[NSSWF:
			NSLS(@"%lu %@, %@ total, %@ available", @"Files info (count, 'item(s)', size, available)"),
			[_files count],
			[_files count] == 1
				? NSLS(@"item", @"Item singular")
				: NSLS(@"items", @"Item plural"),
			[NSString humanReadableStringForSizeInBytes:size],
			[NSString humanReadableStringForSizeInBytes:free]]];
	}
}



- (void)showFiles {
	[_filesTableView reloadData];
}



- (void)selectFileWithName:(NSString *)name {
	[_filesTableView selectRowWithStringValue:name options:NSCaseInsensitiveSearch];
}



- (void)setFiles:(NSArray *)files {
	[_files setArray:files];
}



- (WCFile *)fileAtIndex:(NSUInteger)index {
	NSUInteger	i;
	
	i = ([_filesTableView sortOrder] == WISortDescending)
		? [_files count] - index - 1
		: index;
	
	if(i < [_files count])
		return [_files objectAtIndex:i];
	
	return NULL;
}



- (WCFile *)selectedFile {
	NSInteger		row;

	row = [_filesTableView selectedRow];

	if(row < 0)
		return NULL;

	return [self fileAtIndex:row];
}



- (NSArray *)selectedFiles {
	NSMutableArray		*array;
	NSIndexSet			*indexes;
	NSUInteger			index;

	array = [NSMutableArray array];
	indexes = [_filesTableView selectedRowIndexes];
	index = [indexes firstIndex];
	
	while(index != NSNotFound) {
		[array addObject:[self fileAtIndex:index]];
		
		index = [indexes indexGreaterThanIndex:index];
	}
	
	return array;
}



- (NSArray *)shownFiles {
	return _files;
}



- (void)sortFiles {
	NSTableColumn	*tableColumn;

	tableColumn = [_filesTableView highlightedTableColumn];
	
	if(tableColumn == _nameTableColumn)
		[_files sortUsingSelector:@selector(compareName:)];
	else if(tableColumn == _kindTableColumn)
		[_files sortUsingSelector:@selector(compareKind:)];
	else if(tableColumn == _createdTableColumn)
		[_files sortUsingSelector:@selector(compareCreationDate:)];
	else if(tableColumn == _modifiedTableColumn)
		[_files sortUsingSelector:@selector(compareModificationDate:)];
	else if(tableColumn == _sizeTableColumn)
		[_files sortUsingSelector:@selector(compareSize:)];
}



- (WITableView *)filesTableView {
	return _filesTableView;
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_files count];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_filesTableView setHighlightedTableColumn:tableColumn];
	[self sortFiles];
	[_filesTableView reloadData];
	[delegate validate];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	WCFile		*file;

	file = [self fileAtIndex:row];

	if(tableColumn == _nameTableColumn)
		return [file name];
	else if(tableColumn == _kindTableColumn)
		return [file kind];
	else if(tableColumn == _createdTableColumn)
		return [_dateFormatter stringFromDate:[file creationDate]];
	else if(tableColumn == _modifiedTableColumn)
		return [_dateFormatter stringFromDate:[file modificationDate]];
	else if(tableColumn == _sizeTableColumn) {
		if([file type] == WCFileFile) {
			return [NSString humanReadableStringForSizeInBytes:[file size]];
		} else {
			return [NSSWF:NSLS(@"%llu %@", @"Files folder size (count, 'item(s)'"),
				[file size],
				[file size] == 1
					? NSLS(@"item", @"Item singular")
					: NSLS(@"items", @"Item plural")];
		}
	}
	else if(tableColumn == _serverTableColumn)
		return [[file connection] name];
	
	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if(tableColumn == _nameTableColumn)
		[cell setImage:[[self fileAtIndex:row] iconWithWidth:16.0]];
}



- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(NSInteger)row {
	return [[self fileAtIndex:row] name];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[delegate validate];
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;

	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:NULL];
	[pasteboard setString:[[self selectedFile] name] forType:NSStringPboardType];
}



- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
	NSMutableArray		*sources;
	NSMutableString		*string;
	WCFile				*file;
	NSUInteger			index;

	sources			= [NSMutableArray array];
	string			= [NSMutableString string];
	index			= [indexes firstIndex];
	
	while(index != NSNotFound) {
		file = [self fileAtIndex:index];
		
		if([string length] > 0)
			[string appendString:@"\n"];

		[string appendString:[file path]];
		[sources addObject:file];
		
		index = [indexes indexGreaterThanIndex:index];
	}

	[pasteboard declareTypes:[NSArray arrayWithObjects:
		WCFilePboardType, NSStringPboardType, NSFilesPromisePboardType, NULL] owner:NULL];
	[pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:sources] forType:WCFilePboardType];
	[pasteboard setString:string forType:NSStringPboardType];
	[pasteboard setPropertyList:[NSArray arrayWithObject:NSFileTypeForHFSTypeCode('\0\0\0\0')] forType:NSFilesPromisePboardType];
	
	return YES;
}



- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)proposedRow proposedDropOperation:(NSTableViewDropOperation)proposedOperation {
	return [delegate tableView:tableView validateDrop:info proposedRow:proposedRow proposedDropOperation:proposedOperation];
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
	return [delegate tableView:tableView acceptDrop:info row:row dropOperation:operation];
}



- (NSArray *)tableView:(NSTableView *)tableView namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination forDraggedRowsWithIndexes:(NSIndexSet *)indexes {
	return [delegate tableView:tableView namesOfPromisedFilesDroppedAtDestination:destination forDraggedRowsWithIndexes:indexes];
}

@end
