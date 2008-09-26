/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

@implementation WCError

+ (id)errorWithWiredMessage:(WIP7Message *)message {
	WIP7Enum		error;
	NSUInteger		code;
	
	if(![[message name] isEqualToString:@"wired.error"])
		return NULL;
	
	[message getEnum:&error forName:@"wired.error"];
	
	switch(error) {
		case 0:		code = WCWiredProtocolInternalError;				break;
		case 1:		code = WCWiredProtocolInvalidMessage;				break;
		case 2:		code = WCWiredProtocolUnrecognizedMessage;			break;
		case 3:		code = WCWiredProtocolMessageOutOfSequence;			break;
		case 4:		code = WCWiredProtocolLoginFailed;					break;
		case 5:		code = WCWiredProtocolPermissionDenied;				break;
		case 6:		code = WCWiredProtocolChatNotFound;					break;
		case 7:		code = WCWiredProtocolUserNotFound;					break;
		case 8:		code = WCWiredProtocolUserCannotBeDisconnected;		break;
		case 9:		code = WCWiredProtocolFileNotFound;					break;
		case 10:	code = WCWiredProtocolFileExists;					break;
		case 11:	code = WCWiredProtocolAccountNotFound;				break;
		case 12:	code = WCWiredProtocolAccountExists;				break;
		case 13:	code = WCWiredProtocolTrackerNotEnabled;			break;
		case 14:	code = WCWiredProtocolBanNotFound;					break;
		case 15:	code = WCWiredProtocolBanExists;					break;
		default:	code = error;										break;
	}
	
	return [self errorWithDomain:WCWiredProtocolErrorDomain code:code];
}



#pragma mark -

- (NSString *)localizedDescription {
	if([[self domain] isEqualToString:WCWiredClientErrorDomain]) {
		switch([self code]) {
			case WCWiredClientServerDisconnected:
				return NSLS(@"Server Disconnected", @"WCWiredClientServerDisconnected title");
				break;
				
			case WCWiredClientOpenFailed:
				return NSLS(@"Open Failed", @"XXX title");
				break;
				
			case WCWiredClientCreateFailed:
				return NSLS(@"Create Failed", @"XXX title");
				break;
				
			case WCWiredClientFileExists:
				return NSLS(@"File Exists", @"XXX title");
				break;
				
			case WCWiredClientFolderExists:
				return NSLS(@"Folder Exists", @"XXX title");
				break;
				
			case WCWiredClientTransferExists:
				return NSLS(@"Transfer Exists", @"XXX title");
				break;
				
			case WCWiredClientTransferWithResourceFork:
				return NSLS(@"Transfer Not Supported", @"XXX title");
				break;
				
			case WCWiredClientTransferFailed:
				return NSLS(@"Transfer Failed", @"XXX title");
				break;
				
			case WCWiredClientClientNotFound: 
				return NSLS(@"Client Not Found", @"WCWiredClientClientNotFound title"); 
				break; 

			default:
				break;
		}
	}
	else if([[self domain] isEqualToString:WCWiredProtocolErrorDomain]) {
		switch([self code]) {
			case WCWiredProtocolInternalError:
				return NSLS(@"Internal Server Error", @"Wired protocol error title");
				break;
		
			case WCWiredProtocolInvalidMessage:
				return NSLS(@"Invalid Message", @"Wired protocol error title");
				break;
		
			case WCWiredProtocolUnrecognizedMessage:
				return NSLS(@"Unrecognized Message", @"Wired protocol error title");
				break;
			
			case WCWiredProtocolMessageOutOfSequence:
				return NSLS(@"Message Out of Sequence", @"Wired protocol error title");
				break;
			
			case WCWiredProtocolLoginFailed:
				return NSLS(@"Login Failed", @"Wired protocol error title");
				break;
			
			case WCWiredProtocolPermissionDenied:
				return NSLS(@"Permission Denied", @"Wired protocol error title");
				break;
			
			case WCWiredProtocolChatNotFound:
				return NSLS(@"Chat Not Found", @"Wired protocol error title");
				break;
			
			case WCWiredProtocolUserNotFound:
				return NSLS(@"User Not Found", @"Wired protocol error title");
				break;
			
			case WCWiredProtocolUserCannotBeDisconnected:
				return NSLS(@"Cannot Be Disconnected", @"Wired protocol error title");
				break;
		
			case WCWiredProtocolFileNotFound:
				return NSLS(@"File or Folder Not Found", @"Wired protocol error title");
				break;
		
			case WCWiredProtocolFileExists:
				return NSLS(@"File or Folder Exists", @"Wired protocol error title");
				break;
				
			case WCWiredProtocolAccountNotFound:
				return NSLS(@"Account Not found", @"Wired protocol error title");
				break;
				
			case WCWiredProtocolAccountExists:
				return NSLS(@"Account Exists", @"Wired protocol error title");
				break;
			
			case WCWiredProtocolTrackerNotEnabled:
				return NSLS(@"Tracker Not Enabled", @"Wired protocol error title");
				break;

			case WCWiredProtocolBanNotFound:
				return NSLS(@"Ban Not Found", @"Wired protocol error title");
				break;
			
			case WCWiredProtocolBanExists:
				return NSLS(@"Ban Exists", @"Wired protocol error title");
				break;
			
			default:
				return NSLS(@"Unknown Error", @"Wired protocol error title");
				break;
		}
	}
	
	return [super localizedDescription];
}



- (NSString *)localizedFailureReason {
	id		argument;
	
	argument = [[self userInfo] objectForKey:WIArgumentErrorKey];

	if([[self domain] isEqualToString:WCWiredClientErrorDomain]) {
		switch([self code]) {
			case WCWiredClientServerDisconnected:
				return NSLS(@"The server has unexpectedly disconnected.", @"WCWiredClientServerDisconnected description");
				break;
				
			case WCWiredClientOpenFailed:
				return [NSSWF:NSLS(@"Could not open the file \"%@\".", @"WCWiredClientOpenFailed description (path)"),
					argument];
				break;
				
			case WCWiredClientCreateFailed:
				return [NSSWF:NSLS(@"Could not create the file \"%@\".", @"WCWiredClientCreateFailed description (path)"),
					argument];
				break;
				
			case WCWiredClientFileExists:
				return [NSSWF:NSLS(@"The file \"%@\" already exists.", @"WCWiredClientFileExists description (path)"),
					argument];
				break;
				
			case WCWiredClientFolderExists:
				return [NSSWF:NSLS(@"The folder \"%@\" already exists.", @"WCWiredClientFolderExists description (path)"),
					argument];
				break;
				
			case WCWiredClientTransferExists:
				return [NSSWF:NSLS(@"You are already transferring \"%@\".", @"WCWiredClientTransferExists description (path)"),
					argument];
				break;
				
			case WCWiredClientTransferWithResourceFork:
				if([argument isKindOfClass:[NSString class]]) {
					return [NSSWF:NSLS(@"The file \"%@\" has a resource fork, which is not handled by Wired. Only the data part will be uploaded, possibly resulting in a corrupted file. Please use an archiver to ensure the file will be uploaded correctly.", @"WCWiredClientTransferWithResourceFork description (path)"),
						argument];
				}
				else if([argument isKindOfClass:[NSNumber class]]) {
					return [NSSWF:NSLS(@"The folder contains %lu files with resource forks, which are not handled by Wired. Only the data parts will be uploaded, possibly resulting in corrupted files. Please use an archiver to ensure the files will be uploaded correctly.", @"WCWiredClientTransferWithResourceFork description (number)"),
						[argument unsignedIntegerValue]];
				}
				break;

			case WCWiredClientTransferFailed:
				return [NSSWF:NSLS(@"The transfer of \"%@\" failed.", @"WCWiredClientTransferFailed description (name)"),
					argument];
				break;
				
			case WCWiredClientClientNotFound: 
				return NSLS(@"Could not find the client you referred to. Perhaps that client left before the command could be completed.", @"WCWiredClientClientNotFound description"); 
				break; 
				
			default:
				break;
		}
	}
	else if([[self domain] isEqualToString:WCWiredProtocolErrorDomain]) {
		switch([self code]) {
			case WCWiredProtocolInternalError:
				return NSLS(@"The server failed to process a command. The server administrator can check the log for more information.", @"Wired protocol error description");
				break;
		
			case WCWiredProtocolInvalidMessage:
				return NSLS(@"The server could not parse a message. This is probably because of an protocol incompatibility between the client and the server.", @"Wired protocol error description");
				break;
		
			case WCWiredProtocolUnrecognizedMessage:
				return NSLS(@"The server did not recognize a message. This is probably because of an protocol incompatibility between the client and the server.", @"Wired protocol error description");
				break;
			
			case WCWiredProtocolMessageOutOfSequence:
				return NSLS(@"The server received a message out of sequence. This is probably because of an protocol incompatibility between the client and the server.", @"Wired protocol error description");
				break;
			
			case WCWiredProtocolLoginFailed:
				return NSLS(@"Could not login, the user name and/or password you supplied was rejected.", @"Wired protocol error description");
				break;
			
			case WCWiredProtocolPermissionDenied:
				return NSLS(@"The command could not be completed due to insufficient privileges.", @"Wired protocol error description");
				break;
			
			case WCWiredProtocolChatNotFound:
				return NSLS(@"Could not find the chat you referred to. Perhaps the chat has been removed.", @"Wired protocol error description");
				break;
			
			case WCWiredProtocolUserNotFound:
				return NSLS(@"Could not find the user you referred to. Perhaps that user left before the command could be completed.", @"Wired protocol error description");
				break;
			
			case WCWiredProtocolUserCannotBeDisconnected:
				return NSLS(@"The client you tried to disconnect is protected.", @"Wired protocol error description");
				break;
		
			case WCWiredProtocolFileNotFound:
				return NSLS(@"Could not find the file or folder you referred to. Perhaps someone deleted it.", @"Wired protocol error description");
				break;
		
			case WCWiredProtocolFileExists:
				return NSLS(@"Could not create the file or folder, it already exists.", @"Wired protocol error description");
				break;
				
			case WCWiredProtocolAccountNotFound:
				return NSLS(@"Could not find the account you referred to. Perhaps someone deleted it.", @"Wired protocol error description");
				break;
				
			case WCWiredProtocolAccountExists:
				return NSLS(@"The account you tried to create already exists on the server.", @"Wired protocol error description");
				break;
			
			case WCWiredProtocolTrackerNotEnabled:
				return NSLS(@"This server does not function as a tracker.", @"Wired protocol error description");
				break;

			case WCWiredProtocolBanNotFound:
				return NSLS(@"Could not find the ban you referred to. Perhaps someone deleted it.", @"Wired protocol error description");
				break;
			
			case WCWiredProtocolBanExists:
				return NSLS(@"The ban you tried to create already exists on the server", @"Wired protocol error description");
				break;
			
			default:
                return [NSSWF:NSLS(@"An unknown server error occured. The error received from the server was %u.", @"Wired protocol error description (code)"), [self code]];
                break;
		}
	}
	
	return [super localizedFailureReason];
}


@end
