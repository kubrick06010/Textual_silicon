#import "IRCIsonBatcher.h"

NSErrorDomain const IRCIsonBatcherErrorDomain = @"IRCIsonBatcherErrorDomain";

@interface IRCIsonBatch ()
@property (readwrite, copy) NSArray<NSString *> *nicknames;
@property (readwrite, copy) NSString *commandBody;
@property (readwrite, copy) NSData *encodedBody;
@property (readwrite) IRCIsonBatchEncodingSelection encodingSelection;

- (instancetype)initWithNicknames:(NSArray<NSString *> *)nicknames
				   commandBody:(NSString *)commandBody
				   encodedBody:(NSData *)encodedBody
			 encodingSelection:(IRCIsonBatchEncodingSelection)encodingSelection;
@end

@implementation IRCIsonBatch

- (instancetype)initWithNicknames:(NSArray<NSString *> *)nicknames
				   commandBody:(NSString *)commandBody
				   encodedBody:(NSData *)encodedBody
			 encodingSelection:(IRCIsonBatchEncodingSelection)encodingSelection
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

static NSError *IRCIsonBatcherMakeError(IRCIsonBatcherError code, NSString *nickname, NSUInteger index)
{
	NSArray<NSString *> *descriptions = @[
		@"",
		@"An ISON nickname cannot be empty or contain spaces.",
		@"An ISON nickname cannot be represented using either connection encoding.",
		@"An ISON nickname cannot fit within the IRC line byte limit.",
	];

	return [NSError errorWithDomain:IRCIsonBatcherErrorDomain
							 code:code
						 userInfo:@{
		NSLocalizedDescriptionKey: descriptions[code],
		@"nickname": nickname,
		@"index": @(index),
	}];
}

static NSData * _Nullable IRCIsonBatcherEncode(
	NSString *command,
	IRCIsonBatchEncodingPolicy policy,
	IRCIsonBatchEncodingSelection *selection)
{
	NSData *encodedBody = [command dataUsingEncoding:policy.primaryEncoding allowLossyConversion:NO];

	if (encodedBody) {
		*selection = IRCIsonBatchEncodingSelectionPrimary;
		return encodedBody;
	}

	encodedBody = [command dataUsingEncoding:policy.fallbackEncoding allowLossyConversion:NO];

	if (encodedBody) {
		*selection = IRCIsonBatchEncodingSelectionFallback;
	}

	return encodedBody;
}

static IRCIsonBatch *IRCIsonBatcherCreateBatch(
	NSArray<NSString *> *nicknames,
	NSString *commandBody,
	NSData *encodedBody,
	IRCIsonBatchEncodingSelection selection)
{
	return [[IRCIsonBatch alloc] initWithNicknames:nicknames
									 commandBody:commandBody
									 encodedBody:encodedBody
								 encodingSelection:selection];
}

NSArray<IRCIsonBatch *> *IRCIsonBatchesForNicknames(
	NSArray<NSString *> *nicknames,
	IRCIsonBatchEncodingPolicy encodingPolicy,
	NSUInteger maximumBodyBytes,
	NSError **error)
{
	NSCParameterAssert(nicknames != nil);

	NSMutableArray<IRCIsonBatch *> *batches = [NSMutableArray array];
	NSMutableArray<NSString *> *currentNicknames = [NSMutableArray array];
	NSString *currentCommand = nil;
	NSData *currentEncodedBody = nil;
	IRCIsonBatchEncodingSelection currentSelection = IRCIsonBatchEncodingSelectionPrimary;

	for (NSUInteger index = 0; index < nicknames.count; index++) {
		NSString *nickname = nicknames[index];

		if (nickname.length == 0 || [nickname rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) {
			if (error) {
				*error = IRCIsonBatcherMakeError(IRCIsonBatcherErrorInvalidNickname, nickname, index);
			}
			return nil;
		}

		NSString *candidate = currentCommand ? [currentCommand stringByAppendingFormat:@" %@", nickname] : [@"ISON " stringByAppendingString:nickname];
		IRCIsonBatchEncodingSelection candidateSelection;
		NSData *candidateData = IRCIsonBatcherEncode(candidate, encodingPolicy, &candidateSelection);

		if (candidateData == nil) {
			if (error) {
				*error = IRCIsonBatcherMakeError(IRCIsonBatcherErrorUnencodableNickname, nickname, index);
			}
			return nil;
		}

		if (candidateData.length <= maximumBodyBytes) {
			[currentNicknames addObject:nickname];
			currentCommand = candidate;
			currentEncodedBody = candidateData;
			currentSelection = candidateSelection;
			continue;
		}

		if (currentCommand) {
			[batches addObject:IRCIsonBatcherCreateBatch(currentNicknames, currentCommand, currentEncodedBody, currentSelection)];
			[currentNicknames removeAllObjects];

			candidate = [@"ISON " stringByAppendingString:nickname];
			candidateData = IRCIsonBatcherEncode(candidate, encodingPolicy, &candidateSelection);
		}

		if (candidateData.length > maximumBodyBytes) {
			if (error) {
				*error = IRCIsonBatcherMakeError(IRCIsonBatcherErrorNicknameExceedsByteLimit, nickname, index);
			}
			return nil;
		}

		[currentNicknames addObject:nickname];
		currentCommand = candidate;
		currentEncodedBody = candidateData;
		currentSelection = candidateSelection;
	}

	if (currentCommand) {
		[batches addObject:IRCIsonBatcherCreateBatch(currentNicknames, currentCommand, currentEncodedBody, currentSelection)];
	}

	return [batches copy];
}
