@import XCTest;

#import "IRCMonitorBatcher.h"

@interface IRCMonitorBatcherTests : XCTestCase
@end

@implementation IRCMonitorBatcherTests

- (IRCMonitorBatchEncodingPolicy)utf8Policy
{
	return IRCMonitorBatchEncodingPolicyMake(NSUTF8StringEncoding, NSISOLatin1StringEncoding);
}

- (void)testEmptyInputProducesNoBatches
{
	XCTAssertEqualObjects(IRCMonitorBatchesForNicknames(@[], YES, self.utf8Policy, 510, NULL), @[]);
}

- (void)testBuildsAddAndRemoveCommandsWithCommaSeparatedTargets
{
	IRCMonitorBatch *addition = IRCMonitorBatchesForNicknames(@[@"alice", @"bob"], YES, self.utf8Policy, 510, NULL).firstObject;
	IRCMonitorBatch *removal = IRCMonitorBatchesForNicknames(@[@"alice", @"bob"], NO, self.utf8Policy, 510, NULL).firstObject;

	XCTAssertEqualObjects(addition.commandBody, @"MONITOR + alice,bob");
	XCTAssertEqualObjects(removal.commandBody, @"MONITOR - alice,bob");
	XCTAssertEqualObjects(addition.nicknames, (@[@"alice", @"bob"]));
}

- (void)testPreservesOrderAcrossByteLimitedBatches
{
	NSArray<IRCMonitorBatch *> *batches = IRCMonitorBatchesForNicknames(@[@"aa", @"bb", @"cc"], YES, self.utf8Policy, 14, NULL);

	XCTAssertEqualObjects([batches valueForKey:@"commandBody"], (@[@"MONITOR + aa", @"MONITOR + bb", @"MONITOR + cc"]));
	XCTAssertEqualObjects([batches valueForKey:@"nicknames"], (@[@[@"aa"], @[@"bb"], @[@"cc"]]));
}

- (void)testSplitsAtEncodedByteBoundary
{
	NSArray<IRCMonitorBatch *> *batches = IRCMonitorBatchesForNicknames(@[@"aa", @"bb"], YES, self.utf8Policy, 12, NULL);

	XCTAssertEqualObjects([batches valueForKey:@"commandBody"], (@[@"MONITOR + aa", @"MONITOR + bb"]));
	for (IRCMonitorBatch *batch in batches) {
		XCTAssertLessThanOrEqual(batch.encodedBody.length, 12U);
	}
}

- (void)testUsesFallbackOnlyWhenPrimaryCannotRepresentBody
{
	IRCMonitorBatchEncodingPolicy policy = IRCMonitorBatchEncodingPolicyMake(NSASCIIStringEncoding, NSUTF8StringEncoding);
	IRCMonitorBatch *batch = IRCMonitorBatchesForNicknames(@[@"🙂"], YES, policy, 510, NULL).firstObject;

	XCTAssertEqual(batch.encodingSelection, IRCMonitorBatchEncodingSelectionFallback);
	XCTAssertEqualObjects(batch.encodedBody, [batch.commandBody dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testRejectsInvalidOrUnencodableTargets
{
	for (NSString *nickname in @[@"", @"not valid", @"contains,comma"]) {
		NSError *error = nil;

		XCTAssertNil(IRCMonitorBatchesForNicknames(@[nickname], YES, self.utf8Policy, 510, &error));
		XCTAssertEqual(error.code, IRCMonitorBatcherErrorInvalidNickname);
	}

	NSError *error = nil;
	IRCMonitorBatchEncodingPolicy asciiPolicy = IRCMonitorBatchEncodingPolicyMake(NSASCIIStringEncoding, NSISOLatin1StringEncoding);

	XCTAssertNil(IRCMonitorBatchesForNicknames(@[@"🙂"], YES, asciiPolicy, 510, &error));
	XCTAssertEqual(error.code, IRCMonitorBatcherErrorUnencodableNickname);
}

- (void)testRejectsTargetWhichCannotFitWithinIRCBodyLimit
{
	NSError *error = nil;

	XCTAssertNil(IRCMonitorBatchesForNicknames(@[@"toolong"], YES, self.utf8Policy, 16, &error));
	XCTAssertEqual(error.code, IRCMonitorBatcherErrorNicknameExceedsByteLimit);
	XCTAssertEqualObjects(error.userInfo[@"nickname"], @"toolong");
}

- (void)testLargeInputRespectsBodyLimitAndFlattensWithoutLoss
{
	NSMutableArray<NSString *> *nicknames = [NSMutableArray array];
	for (NSUInteger index = 0; index < 200; index++) {
		[nicknames addObject:[NSString stringWithFormat:@"user%03lu", (unsigned long)index]];
	}

	NSArray<IRCMonitorBatch *> *batches = IRCMonitorBatchesForNicknames(nicknames, YES, self.utf8Policy, 510, NULL);
	NSMutableArray<NSString *> *flattenedNicknames = [NSMutableArray array];

	XCTAssertGreaterThan(batches.count, 1U);
	for (IRCMonitorBatch *batch in batches) {
		XCTAssertLessThanOrEqual(batch.encodedBody.length, 510U);
		[flattenedNicknames addObjectsFromArray:batch.nicknames];
	}

	XCTAssertEqualObjects(flattenedNicknames, nicknames);
}

@end
