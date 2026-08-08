#import "IRCIsonRoundCoordinator.h"

@interface IRCIsonRound ()
@property (readwrite, strong) NSUUID *identifier;
@property (readwrite) NSUInteger generation;
@property (readwrite) IRCIsonRequestKind kind;
@property (readwrite, copy, nullable) id<NSCopying> context;
@property (readwrite, copy) NSArray<NSString *> *requestedNicknames;
@property (readwrite, copy) NSArray<IRCIsonBatch *> *batches;
@property (readwrite) IRCNicknameCaseMapping caseMapping;
@property (readwrite, getter=isVisible) BOOL visible;
@property (readwrite, getter=isInitial) BOOL initial;

- (instancetype)initWithIdentifier:(NSUUID *)identifier
						 generation:(NSUInteger)generation
							   kind:(IRCIsonRequestKind)kind
							context:(nullable id<NSCopying>)context
						  nicknames:(NSArray<NSString *> *)nicknames
						 batches:(NSArray<IRCIsonBatch *> *)batches
					 caseMapping:(IRCNicknameCaseMapping)caseMapping
						 initial:(BOOL)initial;
@end

@implementation IRCIsonRound

- (instancetype)initWithIdentifier:(NSUUID *)identifier
						 generation:(NSUInteger)generation
							   kind:(IRCIsonRequestKind)kind
							context:(nullable id<NSCopying>)context
						  nicknames:(NSArray<NSString *> *)nicknames
						 batches:(NSArray<IRCIsonBatch *> *)batches
					 caseMapping:(IRCNicknameCaseMapping)caseMapping
						 initial:(BOOL)initial
{
	if ((self = [super init])) {
		_identifier = identifier;
		_generation = generation;
		_kind = kind;
		_context = [context copyWithZone:nil];
		_requestedNicknames = [nicknames copy];
		_batches = [batches copy];
		_caseMapping = caseMapping;
		_visible = (kind == IRCIsonRequestKindManual);
		_initial = initial;
	}

	return self;
}

@end

@interface IRCIsonRoundResult ()
- (instancetype)initWithRound:(IRCIsonRound *)round onlineCasefolds:(NSSet<NSString *> *)onlineCasefolds;
@end

@implementation IRCIsonRoundResult

- (instancetype)initWithRound:(IRCIsonRound *)round onlineCasefolds:(NSSet<NSString *> *)onlineCasefolds
{
	if ((self = [super init])) {
		_round = round;

		NSMutableArray<NSString *> *online = [NSMutableArray array];
		NSMutableArray<NSString *> *offline = [NSMutableArray array];

		for (NSString *nickname in round.requestedNicknames) {
			NSString *identity = IRCNicknameCasefold(nickname, round.caseMapping);
			NSMutableArray<NSString *> *destination = [onlineCasefolds containsObject:identity] ? online : offline;

			[destination addObject:nickname];
		}

		_onlineNicknames = [online copy];
		_offlineNicknames = [offline copy];
	}

	return self;
}

@end

@interface IRCIsonRoundTransition ()
@property (readwrite, strong, nullable) IRCIsonRound *roundToStart;
@property (readwrite, strong, nullable) IRCIsonRoundResult *completedResult;
@property (readwrite) BOOL consumedReply;
@property (readwrite) BOOL coalescedAutomaticRequest;

- (instancetype)initWithRoundToStart:(nullable IRCIsonRound *)roundToStart
					 completedResult:(nullable IRCIsonRoundResult *)completedResult
						consumedReply:(BOOL)consumedReply
		 coalescedAutomaticRequest:(BOOL)coalescedAutomaticRequest;
@end

@implementation IRCIsonRoundTransition

- (instancetype)initWithRoundToStart:(nullable IRCIsonRound *)roundToStart
					 completedResult:(nullable IRCIsonRoundResult *)completedResult
						consumedReply:(BOOL)consumedReply
		 coalescedAutomaticRequest:(BOOL)coalescedAutomaticRequest
{
	if ((self = [super init])) {
		_roundToStart = roundToStart;
		_completedResult = completedResult;
		_consumedReply = consumedReply;
		_coalescedAutomaticRequest = coalescedAutomaticRequest;
	}

	return self;
}

@end

@interface IRCIsonRoundCoordinator ()
@property (readwrite, strong, nullable) IRCIsonRound *activeRound;
@property (readwrite) NSUInteger generation;
@property (nonatomic, strong) NSMutableArray<IRCIsonRound *> *pendingRounds;
@property (nonatomic, strong) NSMutableSet<NSString *> *activeOnlineCasefolds;
@property (nonatomic) NSUInteger repliesRemaining;
@end

@implementation IRCIsonRoundCoordinator

- (instancetype)init
{
	if ((self = [super init])) {
		_pendingRounds = [NSMutableArray array];
		_activeOnlineCasefolds = [NSMutableSet set];
	}

	return self;
}

- (NSUInteger)pendingRoundCount
{
	return self.pendingRounds.count;
}

- (IRCIsonRoundTransition *)transitionWithRoundToStart:(nullable IRCIsonRound *)roundToStart
										 result:(nullable IRCIsonRoundResult *)result
								consumedReply:(BOOL)consumedReply
				 coalescedAutomaticRequest:(BOOL)coalescedAutomaticRequest
{
	return [[IRCIsonRoundTransition alloc] initWithRoundToStart:roundToStart
											 completedResult:result
												consumedReply:consumedReply
									coalescedAutomaticRequest:coalescedAutomaticRequest];
}

- (nullable IRCIsonRoundTransition *)enqueueNicknames:(NSArray<NSString *> *)nicknames
												kind:(IRCIsonRequestKind)kind
											 context:(nullable id<NSCopying>)context
											 initial:(BOOL)initial
									  encodingPolicy:(IRCIsonBatchEncodingPolicy)encodingPolicy
										 caseMapping:(IRCNicknameCaseMapping)caseMapping
							 maximumBodyBytes:(NSUInteger)maximumBodyBytes
											   error:(NSError **)error
{
	NSParameterAssert(nicknames != nil);

	NSMutableArray<NSString *> *uniqueNicknames = [NSMutableArray array];
	NSMutableSet<NSString *> *identities = [NSMutableSet set];

	for (NSString *nickname in nicknames) {
		NSString *identity = IRCNicknameCasefold(nickname, caseMapping);

		if ([identities containsObject:identity]) {
			continue;
		}

		[identities addObject:identity];
		[uniqueNicknames addObject:[nickname copy]];
	}

	if (uniqueNicknames.count == 0) {
		return [self transitionWithRoundToStart:nil result:nil consumedReply:NO coalescedAutomaticRequest:NO];
	}

	NSArray<IRCIsonBatch *> *batches = IRCIsonBatchesForNicknames(uniqueNicknames, encodingPolicy, maximumBodyBytes, error);

	if (batches == nil) {
		return nil;
	}

	NSUInteger pendingAutomaticIndex = NSNotFound;

	if (kind == IRCIsonRequestKindAutomaticTracking) {
		pendingAutomaticIndex = [self pendingAutomaticRoundIndex];

		if (pendingAutomaticIndex != NSNotFound) {
			initial = (initial || self.pendingRounds[pendingAutomaticIndex].isInitial);
		}
	}

	IRCIsonRound *round = [[IRCIsonRound alloc] initWithIdentifier:[NSUUID UUID]
												 generation:self.generation
													   kind:kind
													context:context
												  nicknames:uniqueNicknames
												 batches:batches
												caseMapping:caseMapping
												 initial:initial];

	if (self.activeRound) {
		BOOL replacedAutomaticRequest = NO;

		if (pendingAutomaticIndex != NSNotFound) {
			[self.pendingRounds removeObjectAtIndex:pendingAutomaticIndex];
			replacedAutomaticRequest = YES;
		}

		[self.pendingRounds addObject:round];
		return [self transitionWithRoundToStart:nil result:nil consumedReply:NO coalescedAutomaticRequest:replacedAutomaticRequest];
	}

	[self activateRound:round];

	return [self transitionWithRoundToStart:round result:nil consumedReply:NO coalescedAutomaticRequest:NO];
}

- (IRCIsonRoundTransition *)recordReplyNicknames:(NSArray<NSString *> *)onlineNicknames
								 roundIdentifier:(NSUUID *)roundIdentifier
									  generation:(NSUInteger)generation
{
	NSParameterAssert(onlineNicknames != nil);
	NSParameterAssert(roundIdentifier != nil);

	IRCIsonRound *round = self.activeRound;

	if (round == nil || self.repliesRemaining == 0 ||
		generation != self.generation || generation != round.generation ||
		[round.identifier isEqual:roundIdentifier] == NO)
	{
		return [self transitionWithRoundToStart:nil result:nil consumedReply:NO coalescedAutomaticRequest:NO];
	}

	for (NSString *nickname in onlineNicknames) {
		[self.activeOnlineCasefolds addObject:IRCNicknameCasefold(nickname, round.caseMapping)];
	}

	self.repliesRemaining -= 1;

	if (self.repliesRemaining > 0) {
		return [self transitionWithRoundToStart:nil result:nil consumedReply:YES coalescedAutomaticRequest:NO];
	}

	IRCIsonRoundResult *result = [[IRCIsonRoundResult alloc] initWithRound:round onlineCasefolds:self.activeOnlineCasefolds];
	IRCIsonRound *nextRound = [self finishActiveRoundAndActivateNext];

	return [self transitionWithRoundToStart:nextRound result:result consumedReply:YES coalescedAutomaticRequest:NO];
}

- (IRCIsonRoundTransition *)abortActiveRound
{
	if (self.activeRound == nil) {
		return [self transitionWithRoundToStart:nil result:nil consumedReply:NO coalescedAutomaticRequest:NO];
	}

	IRCIsonRound *nextRound = [self finishActiveRoundAndActivateNext];

	return [self transitionWithRoundToStart:nextRound result:nil consumedReply:NO coalescedAutomaticRequest:NO];
}

- (void)reset
{
	self.generation += 1;
	self.activeRound = nil;
	self.repliesRemaining = 0;
	[self.activeOnlineCasefolds removeAllObjects];
	[self.pendingRounds removeAllObjects];
}

- (NSUInteger)pendingAutomaticRoundIndex
{
	NSUInteger index = 0;

	for (IRCIsonRound *round in self.pendingRounds) {
		if (round.kind == IRCIsonRequestKindAutomaticTracking) {
			return index;
		}

		index += 1;
	}

	return NSNotFound;
}

- (void)activateRound:(IRCIsonRound *)round
{
	self.activeRound = round;
	self.repliesRemaining = round.batches.count;
	[self.activeOnlineCasefolds removeAllObjects];
}

- (nullable IRCIsonRound *)finishActiveRoundAndActivateNext
{
	self.activeRound = nil;
	self.repliesRemaining = 0;
	[self.activeOnlineCasefolds removeAllObjects];

	IRCIsonRound *nextRound = self.pendingRounds.firstObject;

	if (nextRound) {
		[self.pendingRounds removeObjectAtIndex:0];
		[self activateRound:nextRound];
	}

	return nextRound;
}

@end
