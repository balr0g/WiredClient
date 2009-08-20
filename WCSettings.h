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

#define WCNick									@"WCNick"
#define WCStatus								@"WCStatus"
#define WCIcon									@"WCCustomIcon"

#define WCCheckForUpdate						@"WCCheckForUpdate"

#define WCShowConnectAtStartup					@"WCShowConnectAtStartup"
#define WCShowServersAtStartup					@"WCShowTrackersAtStartup"

#define WCConfirmDisconnect						@"WCConfirmDisconnect"
#define WCAutoReconnect							@"WCAutoReconnect"

#define WCTheme									@"WCTheme"

#define WCThemes								@"WCThemes"
#define WCThemesName								@"WCThemesName"
#define WCThemesBuiltinName							@"WCThemesBuiltinName"
#define WCThemesBuiltinVersion						@"WCThemesBuiltinVersion"
#define WCThemesIdentifier							@"WCThemesIdentifier"
#define WCThemesShowSmileys							@"WCThemesShowSmileys"
#define WCThemesChatFont							@"WCThemesChatFont"
#define WCThemesChatTextColor						@"WCThemesChatTextColor"
#define WCThemesChatBackgroundColor					@"WCThemesChatBackgroundColor"
#define WCThemesChatEventsColor						@"WCThemesChatEventsColor"
#define WCThemesChatURLsColor						@"WCThemesChatURLsColor"
#define WCThemesChatTimestampEveryLineColor			@"WCThemesChatTimestampEveryLineColor"
#define WCThemesChatTimestampEveryLine				@"WCThemesChatTimestampEveryLine"
#define WCThemesMessagesFont						@"WCThemesMessagesFont"
#define WCThemesMessagesTextColor					@"WCThemesMessagesTextColor"
#define WCThemesMessagesBackgroundColor				@"WCThemesMessagesBackgroundColor"
#define WCThemesBoardsFont							@"WCThemesBoardsFont"
#define WCThemesBoardsTextColor						@"WCThemesBoardsTextColor"
#define WCThemesBoardsBackgroundColor				@"WCThemesBoardsBackgroundColor"
#define WCThemesUserListIconSize					@"WCThemesUserListIconSize"
#define WCThemesUserListIconSizeLarge					1
#define WCThemesUserListIconSizeSmall					0
#define WCThemesUserListAlternateRows				@"WCThemesUserListAlternateRows"
#define WCThemesFileListAlternateRows				@"WCThemesFileListAlternateRows"
#define WCThemesTransferListShowProgressBar			@"WCThemesTransferListShowProgressBar"
#define WCThemesTransferListAlternateRows			@"WCThemesTransferListAlternateRows"
#define WCThemesTrackerListAlternateRows			@"WCThemesTrackerListAlternateRows"

#define WCMessageConversations					@"WCMessageConversations"
#define WCBroadcastConversations				@"WCBroadcastConversations"

#define WCBookmarks								@"WCBookmarks"
#define WCBookmarksName								@"Name"
#define WCBookmarksAddress							@"Address"
#define WCBookmarksLogin							@"Login"
#define WCBookmarksIdentifier						@"Identifier"
#define WCBookmarksNick								@"Nick"
#define WCBookmarksStatus							@"Status"
#define WCBookmarksAutoConnect						@"AutoJoin"
#define WCBookmarksAutoReconnect					@"AutoReconnect"
#define WCBookmarksTheme							@"Theme"

#define WCChatHistoryScrollback					@"WCHistoryScrollback"
#define WCChatHistoryScrollbackModifier			@"WCHistoryScrollbackModifier"
#define WCChatHistoryScrollbackModifierNone			0
#define WCChatHistoryScrollbackModifierCommand		1
#define WCChatHistoryScrollbackModifierOption		2
#define WCChatHistoryScrollbackModifierControl		3
#define WCChatTabCompleteNicks					@"WCTabCompleteNicks"
#define WCChatTabCompleteNicksString			@"WCTabCompleteNicksString"
#define WCChatTimestampChat						@"WCTimestampChat"
#define WCChatTimestampChatInterval				@"WCTimestampChatInterval"

#define WCHighlights							@"WCHighlights"
#define WCHighlightsPattern							@"WCHighlightsPattern"
#define WCHighlightsColor							@"WCHighlightsColor"

#define WCIgnores								@"WCIgnores"
#define WCIgnoresNick								@"Nick"

#define WCEvents								@"WCEvents"
#define WCEventsEvent								@"WCEventsEvent"
#define WCEventsServerConnected							1
#define WCEventsServerDisconnected						2
#define WCEventsError									3
#define WCEventsUserJoined								4
#define WCEventsUserChangedNick							5
#define WCEventsUserLeft								6
#define WCEventsChatReceived							7
#define WCEventsMessageReceived							8
#define WCEventsBoardPostReceived						9
#define WCEventsBroadcastReceived						10
#define WCEventsTransferStarted							11
#define WCEventsTransferFinished						12
#define WCEventsUserChangedStatus						13
#define WCEventsHighlightedChatReceived					14
#define WCEventsChatInvitationReceived					15
#define WCEventsPlaySound							@"WCEventsPlaySound"
#define WCEventsSound								@"WCEventsSound"
#define WCEventsBounceInDock						@"WCEventsBounceInDock"
#define WCEventsPostInChat							@"WCEventsPostInChat"
#define WCEventsShowDialog							@"WCEventsShowDialog"

#define WCEventsVolume							@"WCEventsVolume"

#define WCTransferList							@"WCTransferList"
#define WCDownloadFolder						@"WCDownloadFolder"
#define WCOpenFoldersInNewWindows				@"WCOpenFoldersInNewWindows"
#define WCQueueTransfers						@"WCQueueTransfers"
#define WCCheckForResourceForks					@"WCCheckForResourceForks"
#define WCRemoveTransfers						@"WCRemoveTransfers"
#define WCFilesStyle							@"WCFilesStyle"
#define WCFilesStyleList							0
#define WCFilesStyleTree							1

#define WCTrackerBookmarks						@"WCTrackerBookmarks"
#define WCTrackerBookmarksName						@"Name"
#define WCTrackerBookmarksAddress					@"Address"
#define WCTrackerBookmarksLogin						@"Login"
#define WCTrackerBookmarksIdentifier				@"Identifier"

#define WCWindowProperties						@"WCWindowProperties"

#define WCReadBoardPosts						@"WCReadBoardPosts"
#define WCBoardFilters							@"WCBoardFilters"

#define WCPlaces								@"WCPlaces"

#define WCDebug									@"WCDebug"


@interface WCSettings : WISettings

+ (NSDictionary *)themeWithIdentifier:(NSString *)identifier;

+ (NSDictionary *)eventWithTag:(NSUInteger)tag;

@end
