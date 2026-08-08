@import XCTest;

#import "IRCIsonRoundCoordinator.h"

@interface IRCIsonRoundCoordinatorTests : XCTestCase
@property (nonatomic, strong) IRCIsonRoundCoordinator *coordinator;
@end


@implementation IRCIsonRoundCoordinatorTests

- (void)setUp
{
	[super setUp];

	self.coordinator = [IRCIsonRoundCoordinator new];
}

- (IRCIsonBatchEncodingPolicy)utf8Policy
{
	return IRCIsonBatchEncodingPolicyMake(NSUTF8StringEncoding, NSISOLatin1StringEncoding);
}

- (IRCIsonRoundTransition *)enqueueNicknames:(NSArray<NSString *> *)nicknames
									 kind:(IRCIsonRequestKind)kind
							maximumBodyBytes:(NSUInteger)maximumBodyBytes
{
	NSError *error = nil;
	IRCIsonRoundTransition *transition = [self.coordinator enqueueNicknames:nicknames
												 kind:kind
											  context:nil
											  initial:NO
										   encodingPolicy:self.utf8Policy
											 caseMapping:IRCNicknameCaseMappingRFC1459
									 maximumBodyBytes:maximumBodyBytes
													error:&error];

	XCTAssertNotNil(transition);
	XCTAssertNil(error);

	return transition;
}

- (IRCIsonRoundTransition *)recordReply:(NSArray<NSString *> *)nicknames forRound:(IRCIsonRound *)round
{
	return [self.coordinator recordReplyNicknames:nicknames
								 roundIdentifier:round.identifier
									  generation:round.generation];
}

- (void)testStartingRoundCapturesMetadataAndProducesUniqueIdentity
{
	IRCIsonRoundTransition *firstTransition = [self.coordinator enqueueNicknames:@[@"alice"]
														 kind:IRCIsonRequestKindManual
													  context:@"manual-context"
													  initial:YES
												   encodingPolicy:self.utf8Policy
													 caseMapping:IRCNicknameCaseMappingASCII
											 maximumBodyBytes:510
														error:NULL];
	IRCIsonRound *firstRound = firstTransition.roundToStart;

	XCTAssertEqual(firstRound, self.coordinator.activeRound);
	XCTAssertNotNil(firstRound.identifier);
	XCTAssertEqual(firstRound.generation, self.coordinator.generation);
	XCTAssertEqual(firstRound.kind, IRCIsonRequestKindManual);
	XCTAssertEqualObjects(firstRound.context, @"manual-context");
	XCTAssertTrue(firstRound.isVisible);
	XCTAssertTrue(firstRound.isInitial);
	XCTAssertEqual(firstRound.caseMapping, IRCNicknameCaseMappingASCII);
	XCTAssertEqualObjects(firstRound.requestedNicknames, (@[@"alice"]));
	XCTAssertEqual(firstRound.batches.count, 1U);

	[self recordReply:@[] forRound:firstRound];
	IRCIsonRound *secondRound = [self enqueueNicknames:@[@"bob"]
												 kind:IRCIsonRequestKindAutomaticTracking
									 maximumBodyBytes:510].roundToStart;

	XCTAssertNotEqualObjects(secondRound.identifier, firstRound.identifier);
	XCTAssertEqual(secondRound.generation, firstRound.generation);
	XCTAssertEqual(secondRound.kind, IRCIsonRequestKindAutomaticTracking);
}

- (void)testEmptyRequestIsNoOp
{
	IRCIsonRoundTransition *transition = [self enqueueNicknames:@[]
												 kind:IRCIsonRequestKindManual
									 maximumBodyBytes:510];

	XCTAssertNil(transition.roundToStart);
	XCTAssertNil(transition.completedResult);
	XCTAssertFalse(transition.consumedReply);
	XCTAssertNil(self.coordinator.activeRound);
	XCTAssertEqual(self.coordinator.pendingRoundCount, 0U);
}

- (void)testRoundDeeplySnapshotsMutableNicknamesAndDeduplicatesByCaseMapping
{
	NSMutableString *mutableNickname = [NSMutableString stringWithString:@"[Nick]"];
	NSMutableArray<NSString *> *input = [NSMutableArray arrayWithObjects:mutableNickname, @"{nICK}", @"Bob", nil];
	IRCIsonRound *round = [self enqueueNicknames:input
											 kind:IRCIsonRequestKindManual
								 maximumBodyBytes:510].roundToStart;

	[mutableNickname setString:@"changed"];
	[input removeAllObjects];

	XCTAssertEqualObjects(round.requestedNicknames, (@[@"[Nick]", @"Bob"]));
	XCTAssertEqualObjects(round.batches.firstObject.nicknames, (@[@"[Nick]", @"Bob"]));
	XCTAssertEqualObjects(round.batches.firstObject.commandBody, @"ISON [Nick] Bob");
}

- (void)testMultipleBatchesCompleteOnlyAfterEveryReplyIncludingEmptyReply
{
	IRCIsonRound *round = [self enqueueNicknames:@[@"aa", @"bb", @"cc"]
											 kind:IRCIsonRequestKindAutomaticTracking
								 maximumBodyBytes:9].roundToStart;

	XCTAssertEqual(round.batches.count, 3U);

	IRCIsonRoundTransition *first = [self recordReply:@[@"AA"] forRound:round];
	XCTAssertTrue(first.consumedReply);
	XCTAssertNil(first.completedResult);
	XCTAssertEqual(self.coordinator.activeRound, round);

	IRCIsonRoundTransition *empty = [self recordReply:@[] forRound:round];
	XCTAssertTrue(empty.consumedReply);
	XCTAssertNil(empty.completedResult);
	XCTAssertEqual(self.coordinator.activeRound, round);

	IRCIsonRoundTransition *last = [self recordReply:@[@"CC"] forRound:round];
	XCTAssertTrue(last.consumedReply);
	XCTAssertEqual(last.completedResult.round, round);
	XCTAssertEqualObjects(last.completedResult.onlineNicknames, (@[@"aa", @"cc"]));
	XCTAssertEqualObjects(last.completedResult.offlineNicknames, (@[@"bb"]));
	XCTAssertNil(self.coordinator.activeRound);
}

- (void)testRepliesAreUnionedAndDeduplicatedUsingRoundCaseMapping
{
	IRCIsonRound *round = [self enqueueNicknames:@[@"[Nick]", @"Caret^", @"ALICE", @"É"]
											 kind:IRCIsonRequestKindAutomaticTracking
								 maximumBodyBytes:13].roundToStart;

	XCTAssertGreaterThan(round.batches.count, 1U);

	IRCIsonRoundTransition *transition = nil;
	for (NSUInteger index = 0; index < round.batches.count; index++) {
		NSArray<NSString *> *reply = (index == 0) ? @[@"{nICK}", @"{NICK}", @"unrequested"] : @[@"caret~", @"alice", @"é"];
		transition = [self recordReply:reply forRound:round];
	}

	XCTAssertNotNil(transition.completedResult);
	XCTAssertEqualObjects(transition.completedResult.onlineNicknames, (@[@"[Nick]", @"Caret^", @"ALICE"]));
	XCTAssertEqualObjects(transition.completedResult.offlineNicknames, (@[@"É"]));
}

- (void)testManualRoundsRemainFIFO
{
	IRCIsonRound *first = [self enqueueNicknames:@[@"first"] kind:IRCIsonRequestKindManual maximumBodyBytes:510].roundToStart;
	[self enqueueNicknames:@[@"second"] kind:IRCIsonRequestKindManual maximumBodyBytes:510];
	[self enqueueNicknames:@[@"third"] kind:IRCIsonRequestKindManual maximumBodyBytes:510];

	XCTAssertEqual(self.coordinator.pendingRoundCount, 2U);

	IRCIsonRoundTransition *firstCompletion = [self recordReply:@[] forRound:first];
	IRCIsonRound *second = firstCompletion.roundToStart;
	XCTAssertEqualObjects(second.requestedNicknames, (@[@"second"]));
	XCTAssertEqual(second.kind, IRCIsonRequestKindManual);

	IRCIsonRoundTransition *secondCompletion = [self recordReply:@[] forRound:second];
	IRCIsonRound *third = secondCompletion.roundToStart;
	XCTAssertEqualObjects(third.requestedNicknames, (@[@"third"]));
	XCTAssertEqual(self.coordinator.pendingRoundCount, 0U);

	[self recordReply:@[] forRound:third];
	XCTAssertNil(self.coordinator.activeRound);
}

- (void)testLatestPendingAutomaticReplacesPreviousAndMovesBehindManualWork
{
	IRCIsonRound *active = [self enqueueNicknames:@[@"active"] kind:IRCIsonRequestKindManual maximumBodyBytes:510].roundToStart;
	IRCIsonRoundTransition *oldAutomatic = [self enqueueNicknames:@[@"old-auto"] kind:IRCIsonRequestKindAutomaticTracking maximumBodyBytes:510];
	IRCIsonRoundTransition *manual = [self enqueueNicknames:@[@"manual"] kind:IRCIsonRequestKindManual maximumBodyBytes:510];
	IRCIsonRoundTransition *newAutomatic = [self enqueueNicknames:@[@"new-auto"] kind:IRCIsonRequestKindAutomaticTracking maximumBodyBytes:510];

	XCTAssertFalse(oldAutomatic.coalescedAutomaticRequest);
	XCTAssertFalse(manual.coalescedAutomaticRequest);
	XCTAssertTrue(newAutomatic.coalescedAutomaticRequest);
	XCTAssertEqual(self.coordinator.pendingRoundCount, 2U);

	IRCIsonRound *next = [self recordReply:@[] forRound:active].roundToStart;
	XCTAssertEqualObjects(next.requestedNicknames, (@[@"manual"]));

	IRCIsonRound *last = [self recordReply:@[] forRound:next].roundToStart;
	XCTAssertEqualObjects(last.requestedNicknames, (@[@"new-auto"]));
	XCTAssertEqual(last.kind, IRCIsonRequestKindAutomaticTracking);
	XCTAssertEqual(self.coordinator.pendingRoundCount, 0U);
}

- (void)testActiveAutomaticIsNotReplacedButItsSinglePendingSuccessorIs
{
	IRCIsonRound *active = [self enqueueNicknames:@[@"active-auto"] kind:IRCIsonRequestKindAutomaticTracking maximumBodyBytes:510].roundToStart;
	IRCIsonRoundTransition *firstPending = [self enqueueNicknames:@[@"pending-one"] kind:IRCIsonRequestKindAutomaticTracking maximumBodyBytes:510];
	IRCIsonRoundTransition *replacement = [self enqueueNicknames:@[@"pending-two"] kind:IRCIsonRequestKindAutomaticTracking maximumBodyBytes:510];

	XCTAssertEqualObjects(self.coordinator.activeRound.identifier, active.identifier);
	XCTAssertFalse(firstPending.coalescedAutomaticRequest);
	XCTAssertTrue(replacement.coalescedAutomaticRequest);
	XCTAssertEqual(self.coordinator.pendingRoundCount, 1U);

	IRCIsonRound *next = [self recordReply:@[] forRound:active].roundToStart;
	XCTAssertEqualObjects(next.requestedNicknames, (@[@"pending-two"]));
}

- (void)testReplacingPendingAutomaticPreservesItsInitialTrackingAssignment
{
	IRCIsonRound *manual = [self enqueueNicknames:@[@"manual"] kind:IRCIsonRequestKindManual maximumBodyBytes:510].roundToStart;
	IRCIsonBatchEncodingPolicy policy = self.utf8Policy;

	[self.coordinator enqueueNicknames:@[@"initial-auto"]
								 kind:IRCIsonRequestKindAutomaticTracking
							  context:nil
							  initial:YES
					   encodingPolicy:policy
						 caseMapping:IRCNicknameCaseMappingRFC1459
				 maximumBodyBytes:510
							error:NULL];

	[self.coordinator enqueueNicknames:@[@"fresh-auto"]
								 kind:IRCIsonRequestKindAutomaticTracking
							  context:nil
							  initial:NO
					   encodingPolicy:policy
						 caseMapping:IRCNicknameCaseMappingRFC1459
				 maximumBodyBytes:510
							error:NULL];

	IRCIsonRound *automatic = [self recordReply:@[] forRound:manual].roundToStart;

	XCTAssertEqualObjects(automatic.requestedNicknames, (@[@"fresh-auto"]));
	XCTAssertTrue(automatic.isInitial);
}

- (void)testAbortDiscardsPartialResultAndStartsNextRoundCleanly
{
	IRCIsonRound *first = [self enqueueNicknames:@[@"aa", @"bb"] kind:IRCIsonRequestKindManual maximumBodyBytes:9].roundToStart;
	[self enqueueNicknames:@[@"next"] kind:IRCIsonRequestKindManual maximumBodyBytes:510];

	IRCIsonRoundTransition *partial = [self recordReply:@[@"aa"] forRound:first];
	XCTAssertTrue(partial.consumedReply);
	XCTAssertNil(partial.completedResult);

	IRCIsonRoundTransition *aborted = [self.coordinator abortActiveRound];
	IRCIsonRound *next = aborted.roundToStart;
	XCTAssertNil(aborted.completedResult);
	XCTAssertFalse(aborted.consumedReply);
	XCTAssertEqualObjects(next.requestedNicknames, (@[@"next"]));

	IRCIsonRoundTransition *completion = [self recordReply:@[] forRound:next];
	XCTAssertEqualObjects(completion.completedResult.onlineNicknames, @[]);
	XCTAssertEqualObjects(completion.completedResult.offlineNicknames, (@[@"next"]));
}

- (void)testAbortWithoutActiveRoundIsNoOp
{
	IRCIsonRoundTransition *transition = [self.coordinator abortActiveRound];

	XCTAssertNil(transition.roundToStart);
	XCTAssertNil(transition.completedResult);
	XCTAssertFalse(transition.consumedReply);
	XCTAssertEqual(self.coordinator.pendingRoundCount, 0U);
}

- (void)testResetClearsAllStateIncrementsGenerationAndRejectsStaleReply
{
	IRCIsonRound *staleRound = [self enqueueNicknames:@[@"stale"] kind:IRCIsonRequestKindManual maximumBodyBytes:510].roundToStart;
	[self enqueueNicknames:@[@"discarded"] kind:IRCIsonRequestKindManual maximumBodyBytes:510];
	NSUInteger oldGeneration = self.coordinator.generation;

	[self.coordinator reset];

	XCTAssertEqual(self.coordinator.generation, oldGeneration + 1);
	XCTAssertNil(self.coordinator.activeRound);
	XCTAssertEqual(self.coordinator.pendingRoundCount, 0U);

	IRCIsonRound *currentRound = [self enqueueNicknames:@[@"current"] kind:IRCIsonRequestKindManual maximumBodyBytes:510].roundToStart;
	IRCIsonRoundTransition *stale = [self.coordinator recordReplyNicknames:@[@"stale"]
														 roundIdentifier:staleRound.identifier
															  generation:staleRound.generation];

	XCTAssertFalse(stale.consumedReply);
	XCTAssertNil(stale.completedResult);
	XCTAssertEqual(self.coordinator.activeRound, currentRound);

	IRCIsonRoundTransition *valid = [self recordReply:@[@"current"] forRound:currentRound];
	XCTAssertTrue(valid.consumedReply);
	XCTAssertEqualObjects(valid.completedResult.onlineNicknames, (@[@"current"]));
}

- (void)testWrongIdentifierOrGenerationCannotConsumeCurrentRound
{
	IRCIsonRound *round = [self enqueueNicknames:@[@"alice"] kind:IRCIsonRequestKindManual maximumBodyBytes:510].roundToStart;

	IRCIsonRoundTransition *wrongIdentifier = [self.coordinator recordReplyNicknames:@[@"alice"]
															 roundIdentifier:[NSUUID UUID]
																  generation:round.generation];
	IRCIsonRoundTransition *wrongGeneration = [self.coordinator recordReplyNicknames:@[@"alice"]
															 roundIdentifier:round.identifier
																  generation:round.generation + 1];

	XCTAssertFalse(wrongIdentifier.consumedReply);
	XCTAssertFalse(wrongGeneration.consumedReply);
	XCTAssertEqual(self.coordinator.activeRound, round);

	IRCIsonRoundTransition *valid = [self recordReply:@[@"alice"] forRound:round];
	XCTAssertTrue(valid.consumedReply);
	XCTAssertNotNil(valid.completedResult);
}

- (void)testReplyWithoutActiveRoundIsNotConsumed
{
	IRCIsonRoundTransition *transition = [self.coordinator recordReplyNicknames:@[@"alice"]
														 roundIdentifier:[NSUUID UUID]
															  generation:self.coordinator.generation];

	XCTAssertFalse(transition.consumedReply);
	XCTAssertNil(transition.roundToStart);
	XCTAssertNil(transition.completedResult);
	XCTAssertNil(self.coordinator.activeRound);
}

- (void)testBatchingErrorDoesNotMutateActiveRoundOrQueue
{
	IRCIsonRound *active = [self enqueueNicknames:@[@"active"] kind:IRCIsonRequestKindManual maximumBodyBytes:510].roundToStart;
	NSError *error = nil;
	IRCIsonBatchEncodingPolicy asciiOnly = IRCIsonBatchEncodingPolicyMake(NSASCIIStringEncoding, NSISOLatin1StringEncoding);

	IRCIsonRoundTransition *transition = [self.coordinator enqueueNicknames:@[@"🙂"]
														 kind:IRCIsonRequestKindManual
													  context:nil
													  initial:NO
														   encodingPolicy:asciiOnly
															 caseMapping:IRCNicknameCaseMappingASCII
													 maximumBodyBytes:510
																	error:&error];

	XCTAssertNil(transition);
	XCTAssertEqual(error.code, IRCIsonBatcherErrorUnencodableNickname);
	XCTAssertEqual(self.coordinator.activeRound, active);
	XCTAssertEqual(self.coordinator.pendingRoundCount, 0U);

	IRCIsonRoundTransition *completion = [self recordReply:@[] forRound:active];
	XCTAssertNotNil(completion.completedResult);
}

- (void)testBatchingErrorWhileIdleLeavesCoordinatorIdle
{
	NSError *error = nil;

	IRCIsonRoundTransition *transition = [self.coordinator enqueueNicknames:@[@"too-long"]
														 kind:IRCIsonRequestKindAutomaticTracking
													  context:nil
													  initial:YES
														   encodingPolicy:self.utf8Policy
															 caseMapping:IRCNicknameCaseMappingRFC1459
													 maximumBodyBytes:8
																	error:&error];

	XCTAssertNil(transition);
	XCTAssertEqual(error.code, IRCIsonBatcherErrorNicknameExceedsByteLimit);
	XCTAssertNil(self.coordinator.activeRound);
	XCTAssertEqual(self.coordinator.pendingRoundCount, 0U);
	XCTAssertEqual(self.coordinator.generation, 0U);
}

@end
