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

@class WCErrorQueue, WCFile, WCTransfer;

@interface WCTransfers : WIWindowController {
	IBOutlet WITableView					*_transfersTableView;
	IBOutlet NSTableColumn					*_iconTableColumn;
	IBOutlet NSTableColumn					*_infoTableColumn;
	
	WCErrorQueue							*_errorQueue;

	NSMutableArray							*_transfers;
	NSUInteger								_running;

	NSImage									*_folderImage, *_lockedImage, *_unlockedImage;
	NSTimer									*_timer;
	NSLock									*_lock;
}

+ (BOOL)canPreviewFileWithExtension:(NSString *)extension;

+ (id)transfers;

- (BOOL)downloadFile:(WCFile *)file;
- (BOOL)downloadFile:(WCFile *)file toFolder:(NSString *)destination;
- (BOOL)previewFile:(WCFile *)file;
- (BOOL)uploadPath:(NSString *)path toFolder:(WCFile *)destination;

- (IBAction)start:(id)sender;
- (IBAction)pause:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)remove:(id)sender;
- (IBAction)clear:(id)sender;
- (IBAction)connect:(id)sender;
- (IBAction)revealInFinder:(id)sender;
- (IBAction)revealInFiles:(id)sender;

@end
