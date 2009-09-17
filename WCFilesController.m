/* $Id$ */

/*
 *  Copyright (c) 2006-2009 Axel Andersson
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
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCFilesController.h"
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
	[_filesOutlineView setAllowsUserCustomization:YES];
	[_filesOutlineView setDefaultHighlightedTableColumnIdentifier:@"Name"];
	[_filesOutlineView setDefaultTableColumnIdentifiers:
		[NSArray arrayWithObjects:@"Name", @"Size", NULL]];
	[_filesOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	[_filesOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];

	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
}



#pragma mark -

- (void)themeDidChange:(NSDictionary *)theme {
	[_filesOutlineView setUsesAlternatingRowBackgroundColors:[theme boolForKey:WCThemesFileListAlternateRows]];
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
			size += [file totalSize];

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
	[_filesOutlineView reloadData];
}



- (void)selectFileWithName:(NSString *)name {
	[_filesOutlineView selectRowWithStringValue:name options:NSCaseInsensitiveSearch];
}



- (void)setFiles:(NSArray *)files {
	[_files setArray:files];
}



- (WCFile *)fileAtIndex:(NSUInteger)index {
	NSUInteger	i;
	
	i = ([_filesOutlineView sortOrder] == WISortDescending)
		? [_files count] - index - 1
		: index;
	
	if(i < [_files count])
		return [_files objectAtIndex:i];
	
	return NULL;
}



- (WCFile *)selectedFile {
	NSInteger		row;

	row = [_filesOutlineView selectedRow];

	if(row < 0)
		return NULL;

	return [self fileAtIndex:row];
}



- (NSArray *)selectedFiles {
	NSMutableArray		*array;
	NSIndexSet			*indexes;
	NSUInteger			index;

	array = [NSMutableArray array];
	indexes = [_filesOutlineView selectedRowIndexes];
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

	tableColumn = [_filesOutlineView highlightedTableColumn];
	
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



- (WIOutlineView *)filesOutlineView {
	return _filesOutlineView;
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(item)
		return 0;
	
	return [_files count];
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if(item)
		return NULL;
	
	return [self fileAtIndex:index];
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	WCFile		*file = item;

	if(tableColumn == _nameTableColumn)
		return [file name];
	else if(tableColumn == _kindTableColumn)
		return [file kind];
	else if(tableColumn == _createdTableColumn)
		return [_dateFormatter stringFromDate:[file creationDate]];
	else if(tableColumn == _modifiedTableColumn)
		return [_dateFormatter stringFromDate:[file modificationDate]];
	else if(tableColumn == _sizeTableColumn)
		return [file humanReadableSize];
	else if(tableColumn == _serverTableColumn)
		return [[file connection] name];
	
	return NULL;
}



- (id)outlineView:(NSOutlineView *)outlineView stringValueForRow:(NSInteger)row {
	return [[self fileAtIndex:row] name];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	WCFile		*file = item;
	
	if(tableColumn == _nameTableColumn)
		[cell setImage:[file iconWithWidth:16.0]];
}



- (NSColor *)outlineView:(NSOutlineView *)outlineView backgroundColorForItem:(id)item {
	WCFile		*file = item;
	
	switch([file label]) {
		case WCFileLabelRed:
			return [NSColor colorWithCalibratedRed:249.0 / 255.0 green:92.0 / 255.0 blue:91.0 / 255.0 alpha:1.0];
			break;
		
		case WCFileLabelOrange:
			return [NSColor colorWithCalibratedRed:245.0 / 255.0 green:168.0 / 255.0 blue:69.0 / 255.0 alpha:1.0];
			break;
		
		case WCFileLabelYellow:
			return [NSColor colorWithCalibratedRed:237.0 / 255.0 green:219.0 / 255.0 blue:73.0 / 255.0 alpha:1.0];
			break;
		
		case WCFileLabelGreen:
			return [NSColor colorWithCalibratedRed:178.0 / 255.0 green:217.0 / 255.0 blue:72.0 / 255.0 alpha:1.0];
			break;
		
		case WCFileLabelBlue:
			return [NSColor colorWithCalibratedRed:90.0 / 255.0 green:161.0 / 255.0 blue:254.0 / 255.0 alpha:1.0];
			break;
		
		case WCFileLabelPurple:
			return [NSColor colorWithCalibratedRed:191.0 / 255.0 green:137.0 / 255.0 blue:215.0 / 255.0 alpha:1.0];
			break;
		
		case WCFileLabelGray:
			return [NSColor colorWithCalibratedRed:168.0 / 255.0 green:92.0 / 168.0 blue:91.0 / 168.0 alpha:1.0];
			break;
		
		default:
			return NULL;
			break;
	}
	
	return NULL;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	WCFile		*file = item;
	
	return [file isFolder];
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	[delegate validate];
}



- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_filesOutlineView setHighlightedTableColumn:tableColumn];
	[self sortFiles];
	[_filesOutlineView reloadData];
	[delegate validate];
}



- (BOOL)outlineView:(NSOutlineView *)tableView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	NSEnumerator		*enumerator;
	NSMutableString		*string;
	WCFile				*file;

	string			= [NSMutableString string];
	enumerator		= [items objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		if([string length] > 0)
			[string appendString:@"\n"];

		[string appendString:[file path]];
	}

	[pasteboard declareTypes:[NSArray arrayWithObjects:
		WCFilePboardType, NSStringPboardType, NSFilesPromisePboardType, NULL] owner:NULL];
	[pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:items] forType:WCFilePboardType];
	[pasteboard setString:string forType:NSStringPboardType];
	[pasteboard setPropertyList:[NSArray arrayWithObject:NSFileTypeForHFSTypeCode('\0\0\0\0')] forType:NSFilesPromisePboardType];
	
	return YES;
}



- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
	return [delegate outlineView:outlineView validateDrop:info proposedItem:item proposedChildIndex:index];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
	return [delegate outlineView:outlineView acceptDrop:info item:item childIndex:index];
}



- (NSArray *)outlineView:(NSOutlineView *)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination forDraggedItems:(NSArray *)items {
	return [delegate outlineView:outlineView namesOfPromisedFilesDroppedAtDestination:destination forDraggedItems:items];
}

@end
