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

#define WCFilePboardType				@"WCFilePboardType"
#define WCPlacePboardType				@"WCPlacePboardType"


@class WCFile, WCErrorQueue;

@interface WCFiles : WIWindowController {
	IBOutlet NSSegmentedControl			*_historyControl;
	IBOutlet NSSegmentedControl			*_styleControl;
	IBOutlet NSButton					*_downloadButton;
	IBOutlet NSButton					*_uploadButton;
	IBOutlet NSButton					*_infoButton;
	IBOutlet NSButton					*_previewButton;
	IBOutlet NSButton					*_createFolderButton;
	IBOutlet NSButton					*_reloadButton;
	IBOutlet NSButton					*_deleteButton;
	
	IBOutlet WIOutlineView				*_sourceOutlineView;
	IBOutlet NSTableColumn				*_sourceTableColumn;

	IBOutlet NSTabView					*_filesTabView;

	IBOutlet WIOutlineView				*_filesOutlineView;
	IBOutlet NSTableColumn				*_nameTableColumn;
	IBOutlet NSTableColumn				*_kindTableColumn;
	IBOutlet NSTableColumn				*_createdTableColumn;
	IBOutlet NSTableColumn				*_modifiedTableColumn;
	IBOutlet NSTableColumn				*_sizeTableColumn;
	IBOutlet NSTableColumn				*_serverTableColumn;

	IBOutlet WITreeView					*_filesTreeView;
	
	IBOutlet NSTextField				*_statusTextField;
	IBOutlet NSProgressIndicator		*_progressIndicator;
	
	IBOutlet NSPanel					*_createFolderPanel;
	IBOutlet NSTextField				*_nameTextField;
	IBOutlet NSPopUpButton				*_typePopUpButton;
	IBOutlet NSPopUpButton				*_ownerPopUpButton;
	IBOutlet NSPopUpButton				*_ownerPermissionsPopUpButton;
	IBOutlet NSPopUpButton				*_groupPopUpButton;
	IBOutlet NSPopUpButton				*_groupPermissionsPopUpButton;
	IBOutlet NSPopUpButton				*_everyonePermissionsPopUpButton;

	WCErrorQueue						*_errorQueue;
	
	NSMutableDictionary					*_directories;
	NSMutableDictionary					*_files;
	NSMutableArray						*_servers;
	NSMutableArray						*_places;
	NSMutableArray						*_selectFiles;
	
	WCFile								*_currentDirectory;
	
	WIDateFormatter						*_dateFormatter;
}

+ (id)filesWithConnection:(WCServerConnection *)connection file:(WCFile *)file;
+ (id)filesWithConnection:(WCServerConnection *)connection file:(WCFile *)file selectFile:(WCFile *)selectFile;

- (IBAction)enclosingFolder:(id)sender;
- (IBAction)open:(id)sender;

- (IBAction)history:(id)sender;
- (IBAction)style:(id)sender;
- (IBAction)download:(id)sender;
- (IBAction)upload:(id)sender;
- (IBAction)getInfo:(id)sender;
- (IBAction)preview:(id)sender;
- (IBAction)createFolder:(id)sender;
- (IBAction)type:(id)sender;
- (IBAction)reloadFiles:(id)sender;
- (IBAction)deleteFiles:(id)sender;

@end
