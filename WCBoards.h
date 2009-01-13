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

#import "WCConnectionController.h"

@class WCBoardsSplitView, WCBoard;

@interface WCBoards : WIWindowController {
	IBOutlet WCBoardsSplitView			*_boardsSplitView;
	IBOutlet NSView						*_boardsView;
	IBOutlet NSView						*_threadsView;
	IBOutlet WISplitView				*_threadsSplitView;
	IBOutlet NSView						*_threadListView;
	IBOutlet NSView						*_threadView;

	IBOutlet WIOutlineView				*_boardsOutlineView;
	IBOutlet NSTableColumn				*_boardTableColumn;
	
	IBOutlet WITableView				*_threadsTableView;
	IBOutlet NSTableColumn				*_subjectTableColumn;
	IBOutlet NSTableColumn				*_nickTableColumn;
	IBOutlet NSTableColumn				*_timeTableColumn;

	IBOutlet WebView					*_threadWebView;
	
	IBOutlet NSPanel					*_newBoardPanel;
	IBOutlet NSPopUpButton				*_boardLocationPopUpButton;
	IBOutlet NSTextField				*_boardNameTextField;
	
	IBOutlet NSPanel					*_newThreadPanel;
	IBOutlet NSTextField				*_threadStatusTextField;
	IBOutlet NSTextView					*_threadTextView;
	
	WCBoard								*_boards;
	WIDateFormatter						*_dateFormatter;
	
	NSMutableSet						*_receivedBoards;
	
	NSMutableString						*_headerTemplate, *_footerTemplate, *_postTemplate;
}

+ (id)boards;

- (IBAction)newBoard:(id)sender;
- (IBAction)deleteBoard:(id)sender;
- (IBAction)newThread:(id)sender;

@end
