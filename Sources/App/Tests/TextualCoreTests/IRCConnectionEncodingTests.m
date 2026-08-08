@import XCTest;

#import <stdlib.h>
#import <string.h>

#import "IRC.h"
#import "IRCConnection.h"

@interface IRCConnectionEncodingTests : XCTestCase
@end

@implementation IRCConnectionEncodingTests

- (void)testWireDataAppendsCRLFWithoutChangingEncodedBody
{
	NSData *body = [@"ISON Alice" dataUsingEncoding:NSUTF8StringEncoding];
	NSData *wireData = IRCWireDataForEncodedLineBody(body);
	const uint8_t expectedBytes[] = {'I','S','O','N',' ','A','l','i','c','e','\r','\n'};

	XCTAssertEqualObjects(wireData, [NSData dataWithBytes:expectedBytes length:sizeof(expectedBytes)]);
	XCTAssertEqualObjects(body, [@"ISON Alice" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testWireDataAcceptsExactMaximumBodyLength
{
	NSMutableData *body = [NSMutableData dataWithLength:TXMaximumIRCBodyLength];
	memset(body.mutableBytes, 'a', body.length);

	NSData *wireData = IRCWireDataForEncodedLineBody(body);

	XCTAssertEqual(wireData.length, TXMaximumIRCBodyLength + 2);
}

- (void)testWireDataRejectsOversizedBody
{
	NSData *body = [NSData dataWithBytesNoCopy:calloc(TXMaximumIRCBodyLength + 1, 1)
										 length:TXMaximumIRCBodyLength + 1
								 freeWhenDone:YES];

	XCTAssertNil(IRCWireDataForEncodedLineBody(body));
}

- (void)testWireDataRejectsEmbeddedLineDelimiters
{
	XCTAssertNil(IRCWireDataForEncodedLineBody([@"ISON Alice\rPRIVMSG Bob :bad" dataUsingEncoding:NSUTF8StringEncoding]));
	XCTAssertNil(IRCWireDataForEncodedLineBody([@"ISON Alice\nPRIVMSG Bob :bad" dataUsingEncoding:NSUTF8StringEncoding]));
}

@end
