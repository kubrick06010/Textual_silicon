@import XCTest;

#import "IRCConnection.h"
#import "IRC.h"
#import "IRCIsonRoundCoordinator.h"

@interface IRCIsonTransportMock : NSObject
@property (nonatomic, strong) NSMutableArray<NSData *> *wireLines;
@property (nonatomic, assign) BOOL rejectNextSend;

- (BOOL)sendEncodedBody:(NSData *)encodedBody;
- (BOOL)sendBatch:(IRCIsonBatch *)batch;
@end

@implementation IRCIsonTransportMock

- (instancetype)init
{
	if ((self = [super init])) {
		_wireLines = [NSMutableArray array];
	}

	return self;
}

- (BOOL)sendEncodedBody:(NSData *)encodedBody
{
	NSParameterAssert(encodedBody != nil);

	if (self.rejectNextSend) {
		self.rejectNextSend = NO;

		return NO;
	}

	NSData *wireLine = IRCWireDataForEncodedLineBody(encodedBody);

	if (wireLine == nil) {
		return NO;
	}

	[self.wireLines addObject:wireLine];

	return YES;
}

- (BOOL)sendBatch:(IRCIsonBatch *)batch
{
	NSParameterAssert(batch != nil);

	return [self sendEncodedBody:batch.encodedBody];
}

@end

@interface IRCIsonTransportMockTests : XCTestCase
@property (nonatomic, strong) IRCIsonRoundCoordinator *coordinator;
@property (nonatomic, strong) IRCIsonTransportMock *transport;
@end

@implementation IRCIsonTransportMockTests

- (void)setUp
{
	[super setUp];

	self.coordinator = [IRCIsonRoundCoordinator new];
	self.transport = [IRCIsonTransportMock new];
}

- (IRCIsonBatchEncodingPolicy)utf8Policy
{
	return IRCIsonBatchEncodingPolicyMake(NSUTF8StringEncoding, NSISOLatin1StringEncoding);
}

- (IRCIsonRound *)startManualRoundForNicknames:(NSArray<NSString *> *)nicknames
										 maximumBodyBytes:(NSUInteger)maximumBodyBytes
{
	NSError *error = nil;
	IRCIsonRoundTransition *transition = [self.coordinator enqueueNicknames:nicknames
														 kind:IRCIsonRequestKindManual
													  context:nil
													  initial:NO
												 encodingPolicy:self.utf8Policy
													caseMapping:IRCNicknameCaseMappingRFC1459
											maximumBodyBytes:maximumBodyBytes
													   error:&error];

	XCTAssertNotNil(transition);
	XCTAssertNil(error);
	XCTAssertNotNil(transition.roundToStart);

	return transition.roundToStart;
}

- (BOOL)sendAllBatchesForRound:(IRCIsonRound *)round
{
	for (IRCIsonBatch *batch in round.batches) {
		if ([self.transport sendBatch:batch] == NO) {
			return NO;
		}
	}

	return YES;
}

- (NSArray<NSString *> *)wireLinesAsUTF8Strings
{
	NSMutableArray<NSString *> *lines = [NSMutableArray array];

	for (NSData *wireLine in self.transport.wireLines) {
		NSString *line = [[NSString alloc] initWithData:wireLine encoding:NSUTF8StringEncoding];
		XCTAssertNotNil(line);
		[lines addObject:line ?: @""];
	}

	return lines;
}

- (void)testTransportPreservesBatchOrderAndAddsCRLF
{
	IRCIsonRound *round = [self startManualRoundForNicknames:@[@"aa", @"bb", @"cc"] maximumBodyBytes:9];

	XCTAssertEqual(round.batches.count, 3U);
	XCTAssertTrue([self sendAllBatchesForRound:round]);
	XCTAssertEqualObjects([self wireLinesAsUTF8Strings], (@[
		@"ISON aa\r\n",
		@"ISON bb\r\n",
		@"ISON cc\r\n",
	]));

	for (NSData *wireLine in self.transport.wireLines) {
		XCTAssertLessThanOrEqual(wireLine.length, TXMaximumIRCBodyLength + 2);
	}
}

- (void)testEmpty303CompletesRoundAndMarksAllNicknamesOffline
{
	IRCIsonRound *round = [self startManualRoundForNicknames:@[@"alice"] maximumBodyBytes:510];

	XCTAssertTrue([self sendAllBatchesForRound:round]);
	IRCIsonRoundTransition *transition = [self.coordinator recordReplyNicknames:@[]
															 roundIdentifier:round.identifier
																  generation:round.generation];

	XCTAssertTrue(transition.consumedReply);
	XCTAssertEqualObjects(transition.completedResult.onlineNicknames, @[]);
	XCTAssertEqualObjects(transition.completedResult.offlineNicknames, (@[@"alice"]));
}

- (void)testIntermediateTransportErrorStopsWireWrites
{
	IRCIsonRound *round = [self startManualRoundForNicknames:@[@"aa", @"bb", @"cc"] maximumBodyBytes:9];

	XCTAssertTrue([self.transport sendBatch:round.batches[0]]);
	self.transport.rejectNextSend = YES;

	XCTAssertFalse([self.transport sendBatch:round.batches[1]]);
	XCTAssertEqual(self.transport.wireLines.count, 1U);
	XCTAssertEqualObjects([self wireLinesAsUTF8Strings], (@[@"ISON aa\r\n"]));
}

- (void)testLateReplyAfterErrorQuarantineCannotMutateNextGeneration
{
	IRCIsonRound *staleRound = [self startManualRoundForNicknames:@[@"stale"] maximumBodyBytes:510];
	NSUInteger staleGeneration = staleRound.generation;

	self.transport.rejectNextSend = YES;
	XCTAssertFalse([self.transport sendBatch:staleRound.batches.firstObject]);
	[self.coordinator reset];

	IRCIsonRound *currentRound = [self startManualRoundForNicknames:@[@"current"] maximumBodyBytes:510];
	IRCIsonRoundTransition *lateReply = [self.coordinator recordReplyNicknames:@[@"stale"]
														 roundIdentifier:staleRound.identifier
															  generation:staleGeneration];

	XCTAssertFalse(lateReply.consumedReply);
	XCTAssertNil(lateReply.completedResult);
	XCTAssertEqual(self.coordinator.activeRound, currentRound);

	IRCIsonRoundTransition *validReply = [self.coordinator recordReplyNicknames:@[@"current"]
															 roundIdentifier:currentRound.identifier
																  generation:currentRound.generation];

	XCTAssertTrue(validReply.consumedReply);
	XCTAssertEqualObjects(validReply.completedResult.onlineNicknames, (@[@"current"]));
}

- (void)testLateReplyAfterTimeoutResetCannotConsumeNewRound
{
	IRCIsonRound *timedOutRound = [self startManualRoundForNicknames:@[@"timed-out"] maximumBodyBytes:510];
	[self.coordinator reset];

	IRCIsonRound *currentRound = [self startManualRoundForNicknames:@[@"current"] maximumBodyBytes:510];
	IRCIsonRoundTransition *lateReply = [self.coordinator recordReplyNicknames:@[@"timed-out"]
														 roundIdentifier:timedOutRound.identifier
															  generation:timedOutRound.generation];

	XCTAssertFalse(lateReply.consumedReply);
	XCTAssertNil(lateReply.completedResult);
	XCTAssertEqual(self.coordinator.activeRound, currentRound);
}

- (void)testTransportRejectsOversizedEncodedBodyWithoutRecordingIt
{
	NSMutableData *oversizedBody = [NSMutableData dataWithLength:TXMaximumIRCBodyLength + 1];

	XCTAssertFalse([self.transport sendEncodedBody:oversizedBody]);
	XCTAssertEqual(self.transport.wireLines.count, 0U);
}

@end
