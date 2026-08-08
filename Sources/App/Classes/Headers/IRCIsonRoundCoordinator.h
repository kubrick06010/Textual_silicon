#import <Foundation/Foundation.h>

#import "IRCIsonBatcher.h"
#import "IRCNicknameCaseMapping.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IRCIsonRequestKind) {
	IRCIsonRequestKindAutomaticTracking,
	IRCIsonRequestKindManual,
};

@interface IRCIsonRound : NSObject
@property (readonly, strong) NSUUID *identifier;
@property (readonly) NSUInteger generation;
@property (readonly) IRCIsonRequestKind kind;
@property (readonly, copy, nullable) id<NSCopying> context;
@property (readonly, copy) NSArray<NSString *> *requestedNicknames;
@property (readonly, copy) NSArray<IRCIsonBatch *> *batches;
@property (readonly) IRCNicknameCaseMapping caseMapping;
@property (readonly, getter=isVisible) BOOL visible;
@property (readonly, getter=isInitial) BOOL initial;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface IRCIsonRoundResult : NSObject
@property (readonly, strong) IRCIsonRound *round;
@property (readonly, copy) NSArray<NSString *> *onlineNicknames;
@property (readonly, copy) NSArray<NSString *> *offlineNicknames;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface IRCIsonRoundTransition : NSObject
@property (readonly, strong, nullable) IRCIsonRound *roundToStart;
@property (readonly, strong, nullable) IRCIsonRoundResult *completedResult;
@property (readonly) BOOL consumedReply;
@property (readonly) BOOL coalescedAutomaticRequest;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/**
 * Serializes ISON rounds. One RPL_ISON reply is expected for every batch.
 * Instances are intentionally not thread-safe and should remain on IRCClient's queue.
 */
@interface IRCIsonRoundCoordinator : NSObject
@property (readonly, strong, nullable) IRCIsonRound *activeRound;
@property (readonly) NSUInteger pendingRoundCount;
@property (readonly) NSUInteger generation;

- (nullable IRCIsonRoundTransition *)enqueueNicknames:(NSArray<NSString *> *)nicknames
												kind:(IRCIsonRequestKind)kind
											 context:(nullable id<NSCopying>)context
											 initial:(BOOL)initial
									  encodingPolicy:(IRCIsonBatchEncodingPolicy)encodingPolicy
										 caseMapping:(IRCNicknameCaseMapping)caseMapping
							 maximumBodyBytes:(NSUInteger)maximumBodyBytes
											   error:(NSError **)error;

- (IRCIsonRoundTransition *)recordReplyNicknames:(NSArray<NSString *> *)onlineNicknames
								 roundIdentifier:(NSUUID *)roundIdentifier
									  generation:(NSUInteger)generation;
- (IRCIsonRoundTransition *)abortActiveRound;
- (void)reset;
@end

NS_ASSUME_NONNULL_END
