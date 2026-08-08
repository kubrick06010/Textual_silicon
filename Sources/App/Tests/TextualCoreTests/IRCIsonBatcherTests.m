@import XCTest;

#import "IRCIsonBatcher.h"

@interface IRCIsonBatcherTests : XCTestCase
@end


@implementation IRCIsonBatcherTests

- (IRCIsonBatchEncodingPolicy)utf8Policy
{
	return IRCIsonBatchEncodingPolicyMake(NSUTF8StringEncoding, NSISOLatin1StringEncoding);
}

- (void)testEmptyInputProducesNoBatches
{
	XCTAssertEqualObjects(IRCIsonBatchesForNicknames(@[], self.utf8Policy, 510, NULL), @[]);
}

- (void)testNicknamesWhichFitRemainInOneBatch
{
	NSArray<IRCIsonBatch *> *batches = IRCIsonBatchesForNicknames(@[@"alice", @"bob"], self.utf8Policy, 510, NULL);
	IRCIsonBatch *batch = batches.firstObject;

	XCTAssertEqual(batches.count, 1U);
	XCTAssertEqualObjects(batch.nicknames, (@[@"alice", @"bob"]));
	XCTAssertEqualObjects(batch.commandBody, @"ISON alice bob");
	XCTAssertEqualObjects(batch.encodedBody, [batch.commandBody dataUsingEncoding:NSUTF8StringEncoding]);
	XCTAssertEqual(batch.encodingSelection, IRCIsonBatchEncodingSelectionPrimary);
}

- (void)testStartsNewBatchAtByteBoundaryAndPreservesOrder
{
	NSArray<IRCIsonBatch *> *batches = IRCIsonBatchesForNicknames(@[@"aa", @"bb", @"cc"], self.utf8Policy, 9, NULL);

	XCTAssertEqualObjects([batches valueForKey:@"commandBody"], (@[@"ISON aa", @"ISON bb", @"ISON cc"]));
	XCTAssertEqualObjects([batches valueForKey:@"nicknames"], (@[@[@"aa"], @[@"bb"], @[@"cc"]]));
}

- (void)testAcceptsCommandWhichExactlyFitsLimit
{
	IRCIsonBatch *batch = IRCIsonBatchesForNicknames(@[@"nick"], self.utf8Policy, 9, NULL).firstObject;

	XCTAssertEqualObjects(batch.commandBody, @"ISON nick");
	XCTAssertEqual(batch.encodedBody.length, 9U);
}

- (void)testCountsPrimaryEncodingBytesForUnicodeNicknames
{
	NSArray<IRCIsonBatch *> *batches = IRCIsonBatchesForNicknames(@[@"é", @"ø"], self.utf8Policy, 9, NULL);

	XCTAssertEqualObjects([batches valueForKey:@"commandBody"], (@[@"ISON é", @"ISON ø"]));
	for (IRCIsonBatch *batch in batches) {
		XCTAssertLessThanOrEqual(batch.encodedBody.length, 9U);
		XCTAssertEqual(batch.encodingSelection, IRCIsonBatchEncodingSelectionPrimary);
	}
}

- (void)testUsesFallbackOnlyWhenPrimaryCannotRepresentBody
{
	IRCIsonBatchEncodingPolicy policy = IRCIsonBatchEncodingPolicyMake(NSASCIIStringEncoding, NSUTF8StringEncoding);
	IRCIsonBatch *batch = IRCIsonBatchesForNicknames(@[@"🙂"], policy, 510, NULL).firstObject;

	XCTAssertEqual(batch.encodingSelection, IRCIsonBatchEncodingSelectionFallback);
	XCTAssertEqualObjects(batch.encodedBody, [batch.commandBody dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testLargeRoundRespectsIRCBodyLimitWithoutLosingNicknames
{
	NSMutableArray<NSString *> *nicknames = [NSMutableArray array];
	for (NSUInteger index = 0; index < 200; index++) {
		[nicknames addObject:[NSString stringWithFormat:@"user%03lu", (unsigned long)index]];
	}

	NSArray<IRCIsonBatch *> *batches = IRCIsonBatchesForNicknames(nicknames, self.utf8Policy, 510, NULL);
	NSMutableArray<NSString *> *flattenedNicknames = [NSMutableArray array];

	XCTAssertGreaterThan(batches.count, 1U);
	for (IRCIsonBatch *batch in batches) {
		XCTAssertLessThanOrEqual(batch.encodedBody.length, 510U);
		XCTAssertTrue([batch.commandBody hasPrefix:@"ISON "]);
		[flattenedNicknames addObjectsFromArray:batch.nicknames];
	}

	XCTAssertEqualObjects(flattenedNicknames, nicknames);
}

- (void)testRejectsNicknameUnavailableInBothEncodings
{
	NSError *error = nil;
	IRCIsonBatchEncodingPolicy policy = IRCIsonBatchEncodingPolicyMake(NSASCIIStringEncoding, NSISOLatin1StringEncoding);

	XCTAssertNil(IRCIsonBatchesForNicknames(@[@"🙂"], policy, 510, &error));
	XCTAssertEqual(error.code, IRCIsonBatcherErrorUnencodableNickname);
}

- (void)testRejectsNicknameWhichCannotFit
{
	NSError *error = nil;

	XCTAssertNil(IRCIsonBatchesForNicknames(@[@"toolong"], self.utf8Policy, 8, &error));
	XCTAssertEqual(error.code, IRCIsonBatcherErrorNicknameExceedsByteLimit);
	XCTAssertEqualObjects(error.userInfo[@"nickname"], @"toolong");
}

- (void)testRejectsEmptyOrSpaceContainingNickname
{
	for (NSString *nickname in @[@"", @"not valid"]) {
		NSError *error = nil;

		XCTAssertNil(IRCIsonBatchesForNicknames(@[nickname], self.utf8Policy, 510, &error));
		XCTAssertEqual(error.code, IRCIsonBatcherErrorInvalidNickname);
	}
}

@end
