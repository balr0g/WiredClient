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

#import "WCConnection.h"

WIP7Spec							*WCP7Spec;


@implementation WCConnection

+ (NSString *)versionStringForMessage:(WIP7Message *)message {
	NSString		*applicationName, *applicationVersion, *osName, *osVersion, *arch;
	WIP7UInt32		applicationBuild;
	
	applicationName		= [message stringForName:@"wired.info.application.name"];
	applicationVersion	= [message stringForName:@"wired.info.application.version"];
	osName				= [message stringForName:@"wired.info.os.name"];
	osVersion			= [message stringForName:@"wired.info.os.version"];
	arch				= [message stringForName:@"wired.info.arch"];
	
	[message getUInt32:&applicationBuild forName:@"wired.info.application.build"];
	
	return [NSSWF:
		NSLS(@"%@ %@ (%u) on %@ %@ (%@)", @"Wired version (application name, application version, application build, os name, os version, architecture)"),
		applicationName, applicationVersion, applicationBuild,
		osName, osVersion, arch];
}



#pragma mark -

+ (id)connection {
	return [[[self alloc] init] autorelease];
}



#pragma mark -

- (id)init {
	self = [super init];
	
	_uuid = [[NSString UUIDString] retain];
	
	return self;
}



- (void)dealloc {
	[_bookmark release];
	[_url release];
	[_uuid release];
	
	[super dealloc];
}



#pragma mark -

- (void)disconnect {
	[self doesNotRecognizeSelector:_cmd];
}



#pragma mark -

- (WIP7Message *)clientInfoMessage {
	static NSString		*applicationName, *applicationVersion, *osName, *osVersion, *arch;
	static WIP7UInt32	applicationBuild;
	NSBundle			*bundle;
	NSDictionary		*dictionary;
	WIP7Message			*message;
	const NXArchInfo	*archInfo;
	cpu_type_t			cpuType;
	size_t				cpuTypeSize;
	
	if(!applicationName) {
		bundle				= [NSBundle mainBundle];
		dictionary			= [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		cpuTypeSize			= sizeof(cpuType);
		
		if(sysctlbyname("sysctl.proc_cputype", &cpuType, &cpuTypeSize, NULL, 0) < 0)
			cpuType			= NXGetLocalArchInfo()->cputype;
		
		archInfo			= NXGetArchInfoFromCpuType(cpuType, CPU_SUBTYPE_MULTIPLE);
		
		applicationName		= [[bundle objectForInfoDictionaryKey:@"CFBundleExecutable"] retain];
		applicationVersion	= [[bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] retain];
		applicationBuild	= [[bundle objectForInfoDictionaryKey:@"CFBundleVersion"] unsignedIntValue];
		osName				= [[dictionary objectForKey:@"ProductName"] retain];
		osVersion			= [[dictionary objectForKey:@"ProductVersion"] retain];
		arch				= [[NSString alloc] initWithUTF8String:archInfo->name];
	}

	message = [WIP7Message messageWithName:@"wired.client_info" spec:WCP7Spec];
	[message setString:applicationName forName:@"wired.info.application.name"];
	[message setString:applicationVersion forName:@"wired.info.application.version"];
	[message setUInt32:applicationBuild forName:@"wired.info.application.build"];
	[message setString:osName forName:@"wired.info.os.name"];
	[message setString:osVersion forName:@"wired.info.os.version"];
	[message setString:arch forName:@"wired.info.arch"];
	[message setBool:YES forName:@"wired.info.supports_rsrc"];
	
	return message;
}



- (WIP7Message *)setNickMessage {
	NSString		*nick;
	WIP7Message		*message;
	
	nick = [[self bookmark] objectForKey:WCBookmarksNick];
	
	if([nick length] == 0)
		nick = [[WCSettings settings] objectForKey:WCNick];

	message = [WIP7Message messageWithName:@"wired.user.set_nick" spec:WCP7Spec];
	[message setString:nick forName:@"wired.user.nick"];
	
	return message;
}



- (WIP7Message *)setStatusMessage {
	NSString		*status;
	WIP7Message		*message;
	
	status = [[self bookmark] objectForKey:WCBookmarksStatus];
	
	if([status length] == 0)
		status = [[WCSettings settings] objectForKey:WCStatus];

	message = [WIP7Message messageWithName:@"wired.user.set_status" spec:WCP7Spec];
	[message setString:status forName:@"wired.user.status"];
	
	return message;
}



- (WIP7Message *)setIconMessage {
	NSData			*icon;
	WIP7Message		*message;

	icon = [NSData dataWithBase64EncodedString:[[WCSettings settings] objectForKey:WCIcon]];
	message = [WIP7Message messageWithName:@"wired.user.set_icon" spec:WCP7Spec];
	[message setData:icon forName:@"wired.user.icon"];
	
	return message;
}



- (WIP7Message *)loginMessage {
	NSString		*login, *password;
	WIP7Message		*message;
	
	login = ([[[self URL] user] length] > 0) ? [[self URL] user] : WCDefaultLogin;
	password = ([[[self URL] password] length] > 0) ? [[[self URL] password] SHA1] : [@"" SHA1];
	
	message = [WIP7Message messageWithName:@"wired.send_login" spec:WCP7Spec];
	[message setString:login forName:@"wired.user.login"];
	[message setString:password forName:@"wired.user.password"];
	
	return message;
}



#pragma mark -

- (void)setURL:(WIURL *)url {
	[url retain];
	[_url release];
	
	_url = url;
}



- (WIURL *)URL {
	return _url;
}



- (void)setBookmark:(NSDictionary *)bookmark {
	[bookmark retain];
	[_bookmark release];
	
	_bookmark = bookmark;
}



- (NSDictionary *)bookmark {
	return _bookmark;
}



- (WIP7Socket *)socket {
	[self doesNotRecognizeSelector:_cmd];
	
	return NULL;
}



- (NSString *)identifier {
	NSString	*identifier;
	
	identifier = [self bookmarkIdentifier];
	
	if(identifier)
		return identifier;
	
	return [self URLIdentifier];
}



- (NSString *)URLIdentifier {
	return [[[self URL] hostpair] stringByAppendingString:[[self URL] user]];
}



- (NSString *)bookmarkIdentifier {
	return [_bookmark objectForKey:WCBookmarksIdentifier];
}



- (NSString *)uniqueIdentifier {
	return _uuid;
}

@end
