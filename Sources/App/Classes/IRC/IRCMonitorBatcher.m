#import "IRCMonitorBatcher.h"

NSErrorDomain const IRCMonitorBatcherErrorDomain = @"IRCMonitorBatcherErrorDomain";

@interface IRCMonitorBatch ()
@property (readwrite, copy) NSArray<NSString *> *nicknames;
@property (readwrite, copy) NSString *commandBody;
@property (readwrite, copy) NSData *encodedBody;
@property (readwrite) IRCMonitorBatchEncodingSelection encodingSelection;

- (instancetype)initWithNicknames:(NSArray<NSString *> *)nicknames
				   commandBody:(NSString *)commandBody
				   encodedBody:(NSData *)encodedBody
				 encodingSelection:(IRCMonitorBatchEncodingSelection)encodingSelection;
@end

@implementation IRCMonitorBatch

- (instancetype)initWithNicknames:(NSArray<NSString *> *)nicknames
				   commandBody:(NSString *)commandBody
				   encodedBody:(NSData *)encodedBody
				 encodingSelection:(IRCMonitorBatchEncodingSelection)encodingSelection
{
	if ((self = [super init])) {
		_nicknames = [nicknames copy];
		_commandBody = [commandBody copy];
		_encodedBody = [encodedBody copy];
		_encodingSelection = encodingSelection;
	}

	return self;
}

@end

static NSError *IRCMonitorBatcherMakeError(IRCMonitorBatcherError code, NSString *nickname, NSUInteger index)
{
	NSArray<NSString *> *descriptions = @[
		@"",
		@"A MONITOR nickname cannot be empty, contain spaces, or contain commas.",
		@"A MONITOR nickname cannot be represented using either connection encoding.",
		@"A MONITOR nickname cannot fit within the IRC line byte limit.",
	];

	return [NSError errorWithDomain:IRCMonitorBatcherErrorDomain
								 code:code
							 userInfo:@{
								 NSLocalizedDescriptionKey: descriptions[code],
								 @"nickname": nickname,
								 @"index": @(index),
							 }];
}

static NSData * _Nullable IRCMonitorBatcherEncode(
	NSString *command,
	IRCMonitorBatchEncodingPolicy policy,
	IRCMonitorBatchEncodingSelection *selection)
{
	NSData *encodedBody = [command dataUsingEncoding:policy.primaryEncoding allowLossyConversion:NO];

	if (encodedBody) {
		*selection = IRCMonitorBatchEncodingSelectionPrimary;
		return encodedBody;
	}

	encodedBody = [command dataUsingEncoding:policy.fallbackEncoding allowLossyConversion:NO];

	if (encodedBody) {
		*selection = IRCMonitorBatchEncodingSelectionFallback;
	}

	return encodedBody;
}

static IRCMonitorBatch *IRCMonitorBatcherCreateBatch(
	NSArray<NSString *> *nicknames,
	NSString *commandBody,
	NSData *encodedBody,
	IRCMonitorBatchEncodingSelection selection)
{
	return [[IRCMonitorBatch alloc] initWithNicknames:nicknames
									 commandBody:commandBody
									 encodedBody:encodedBody
								 encodingSelection:selection];
}

NSArray<IRCMonitorBatch *> *IRCMonitorBatchesForNicknames(
	NSArray<NSString *> *nicknames,
	BOOL adding,
	IRCMonitorBatchEncodingPolicy encodingPolicy,
	NSUInteger maximumBodyBytes,
	NSError **error)
{
	NSCParameterAssert(nicknames != nil);

	NSString *modifier = adding ? @"+" : @"-";
	NSString *commandPrefix = [NSString stringWithFormat:@"MONITOR %@ ", modifier];

	NSMutableArray<IRCMonitorBatch *> *batches = [NSMutableArray array];
	NSMutableArray<NSString *> *currentNicknames = [NSMutableArray array];
	NSString *currentCommand = nil;
	NSData *currentEncodedBody = nil;
	IRCMonitorBatchEncodingSelection currentSelection = IRCMonitorBatchEncodingSelectionPrimary;

	for (NSUInteger index = 0; index < nicknames.count; index++) {
		NSString *nickname = nicknames[index];

		if (nickname.length == 0 ||
			[nickname rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound ||
			[nickname rangeOfString:@","].location != NSNotFound)
		{
			if (error) {
				*error = IRCMonitorBatcherMakeError(IRCMonitorBatcherErrorInvalidNickname, nickname, index);
			}

			return nil;
		}

		NSString *candidate = nil;

		if (currentCommand) {
			candidate = [currentCommand stringByAppendingFormat:@",%@", nickname];
		} else {
			candidate = [commandPrefix stringByAppendingString:nickname];
		}

		IRCMonitorBatchEncodingSelection candidateSelection;
		NSData *candidateData = IRCMonitorBatcherEncode(candidate, encodingPolicy, &candidateSelection);

		if (candidateData == nil) {
			if (error) {
				*error = IRCMonitorBatcherMakeError(IRCMonitorBatcherErrorUnencodableNickname, nickname, index);
			}

			return nil;
		}

		if (currentCommand && candidateData.length <= maximumBodyBytes) {
			[currentNicknames addObject:nickname];
			currentCommand = candidate;
			currentEncodedBody = candidateData;
			currentSelection = candidateSelection;

			continue;
		}

		if (currentCommand) {
			[batches addObject:IRCMonitorBatcherCreateBatch(currentNicknames, currentCommand, currentEncodedBody, currentSelection)];
			[currentNicknames removeAllObjects];
		}

		candidate = [commandPrefix stringByAppendingString:nickname];
		candidateData = IRCMonitorBatcherEncode(candidate, encodingPolicy, &candidateSelection);

		if (candidateData == nil) {
			if (error) {
				*error = IRCMonitorBatcherMakeError(IRCMonitorBatcherErrorUnencodableNickname, nickname, index);
			}

			return nil;
		}

		if (candidateData.length > maximumBodyBytes) {
			if (error) {
				*error = IRCMonitorBatcherMakeError(IRCMonitorBatcherErrorNicknameExceedsByteLimit, nickname, index);
			}

			return nil;
		}

		[currentNicknames addObject:nickname];
		currentCommand = candidate;
		currentEncodedBody = candidateData;
		currentSelection = candidateSelection;
	}

	if (currentCommand) {
		[batches addObject:IRCMonitorBatcherCreateBatch(currentNicknames, currentCommand, currentEncodedBody, currentSelection)];
	}

	return [batches copy];
}
