/* $Id$ */

/*
 *  Copyright (c) 2009 Axel Andersson
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

#import "WCBoardsTextView.h"
#import "WCFile.h"
#import "WCFiles.h"

@implementation WCBoardsTextView

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)info {
	if([[[info draggingPasteboard] types] containsObject:WCFilePboardType])
		return NSDragOperationCopy;
	
	return [super draggingEntered:info];
}



- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)info {
	if([[[info draggingPasteboard] types] containsObject:WCFilePboardType])
		return NSDragOperationCopy;
	
	return [super draggingUpdated:info];
}



- (BOOL)performDragOperation:(id <NSDraggingInfo>)info {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	NSPasteboard		*pasteboard;
	NSArray				*sources;
	WCFile				*file;
	
	pasteboard = [info draggingPasteboard];
	
	if([[pasteboard types] containsObject:WCFilePboardType]) {
		array		= [NSMutableArray array];
		sources		= [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
		enumerator	= [sources objectEnumerator];
		
		while((file = [enumerator nextObject])) {
			[array addObject:[NSSWF:@"wiredp7://%@%@",
				[[file path] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
				[file isFolder] ? @"/" : @""]];
		}
		
		[pasteboard setString:[array componentsJoinedByString:@", "] forType:NSStringPboardType];
	}
	
	return [super performDragOperation:info];
}

@end
