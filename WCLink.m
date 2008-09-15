/* $Id$ */

/*
 *  Copyright (c) 2005-2007 Axel Andersson
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

#import "WCApplicationController.h"
#import "WCConnection.h"
#import "WCLink.h"

@interface WCLink(Private)

- (void)_schedulePingTimer;
- (void)_invalidatePingTimer;

@end


@implementation WCLink(Private)

- (void)_schedulePingTimer {
	_pingTimer = [[NSTimer scheduledTimerWithTimeInterval:60.0
												   target:self
												 selector:@selector(pingTimer:)
												 userInfo:NULL
												  repeats:YES] retain];
}



- (void)_invalidatePingTimer {
	[_pingTimer invalidate];
}

@end


@implementation WCLink

- (id)initLinkWithURL:(WIURL *)url {
	self = [super init];
	
	_url = [url retain];
	_pingMessage = [[WIP7Message alloc] initWithName:@"wired.send_ping" spec:WCP7Spec];
	
	return self;
}



- (void)dealloc {
	[_url release];
	[_pingTimer release];
	[_pingMessage release];
	
	[super dealloc];
}



#pragma mark -

- (void)setDelegate:(id)delegate {
	_delegate = delegate;
	
	_delegateLinkConnected = [_delegate respondsToSelector:@selector(linkConnected:)];
	_delegateLinkClosed = [_delegate respondsToSelector:@selector(linkClosed:error:)];
	_delegateLinkTerminated = [_delegate respondsToSelector:@selector(linkTerminated:)];
	_delegateLinkSentCommand = [_delegate respondsToSelector:@selector(link:sentMessage:)];
	_delegateLinkReceivedMessage = [_delegate respondsToSelector:@selector(link:receivedMessage:)];
}



- (id)delegate {
	return _delegate;
}



#pragma mark -

- (WIURL *)URL {
	return _url;
}



- (WIP7Socket *)socket {
	return _p7Socket;
}



- (BOOL)isReading {
	return _reading;
}



#pragma mark -

- (void)connect {
	_reading = YES;
	_terminating = NO;
	
	[WIThread detachNewThreadSelector:@selector(linkThread:) toTarget:self withObject:NULL];
}



- (void)disconnect {
	_closing = YES;
	_reading = NO;
}



- (void)terminate {
	_terminating = YES;
	_reading = NO;
}



- (void)sendMessage:(WIP7Message *)message {
	[_p7Socket writeMessage:message timeout:0.0 error:NULL];
	
	if(_delegateLinkSentCommand)
		[_delegate link:self sentMessage:message];
}



#pragma mark -

- (void)linkThread:(id)arg {
	NSAutoreleasePool	*pool, *loopPool = NULL;
	WIError				*error = NULL;
	WIAddress			*address;
	WIP7Message			*message;
	NSUInteger			i = 0;
	NSInteger			code;
	BOOL				failed = NO;

	pool = [[NSAutoreleasePool alloc] init];
	
	[_delegate retain];
	
	address = [WIAddress addressWithString:[_url host] error:&error];
	
	if(!address)
		goto close;
	
	[address setPort:[_url port]];

	_socket = [[WISocket alloc] initWithAddress:address type:WISocketTCP];
	[_socket setInteractive:YES];
	
	if(![_socket connectWithTimeout:30.0 error:&error]) {
		failed = YES;
		
		goto close;
	}
	
	_p7Socket = [[WIP7Socket alloc] initWithSocket:_socket TLS:[WISocketTLS socketTLSForClient] spec:WCP7Spec];
	
	if(![_p7Socket connectWithOptions:WIP7TLS | WIP7CompressionDeflate | WIP7EncryptionRSA_AES256_SHA1 | WIP7ChecksumSHA1
						serialization:WIP7Binary
							 username:[_url user]
							 password:[[_url password] SHA1]
							  timeout:30.0
								error:&error]) {
		failed = YES;
		
		goto close;
	}
	
	if(_delegateLinkConnected)
		[_delegate performSelectorOnMainThread:@selector(linkConnected:) withObject:self];
	
	[self performSelectorOnMainThread:@selector(_schedulePingTimer)];
	
	while(!_closing && !_terminating) {
		if(!loopPool)
			loopPool = [[NSAutoreleasePool alloc] init];
		
		error = NULL;
		message = [_p7Socket readMessageWithTimeout:0.1 error:&error];
		
		if(_closing || _terminating) {
			goto close;
		}
		else if(!message) {
			code = [[[error userInfo] objectForKey:WILibWiredErrorKey] code];

			if(code == ETIMEDOUT) {
				continue;
			}
			else if(code == WI_ERROR_SOCKET_EOF) {
				error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientServerDisconnected];
				
				goto close;
			}
			else {
				failed = YES;
				
				goto close;
			}
		}
		
		if(_delegateLinkReceivedMessage)
			[_delegate performSelectorOnMainThread:@selector(link:receivedMessage:) withObject:self withObject:message];
		
		if(++i % 100 == 0) {
			[loopPool release];
			loopPool = NULL;
		}
	}
	
close:
	[self performSelectorOnMainThread:@selector(_invalidatePingTimer)];
	
	if(_terminating) {
		if(_delegateLinkTerminated)
			[_delegate performSelectorOnMainThread:@selector(linkTerminated:) withObject:self waitUntilDone:YES];
	} else {
		if(_delegateLinkClosed)
			[_delegate performSelectorOnMainThread:@selector(linkClosed:error:) withObject:self withObject:error waitUntilDone:YES];
	}
	
	_reading = NO;

	if(!failed) {
		[_p7Socket close];
		[_socket close];
	}
	
	[_p7Socket release];
	[_socket release];
	
	_p7Socket = NULL;
	_socket = NULL;
	
	[_delegate release];
	[loopPool release];
	[pool release];
}



- (void)pingTimer:(NSTimer *)timer {
	[self sendMessage:_pingMessage];
}

@end
