#import "IRCIsonResultApplicator.h"

@implementation IRCIsonTrackedUserSnapshot

- (instancetype)initWithNickname:(NSString *)nickname online:(BOOL)online
{
	NSParameterAssert(nickname != nil);

	if ((self = [super init])) {
		_nickname = [nickname copy];
		_online = online;
	}

	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

@end


@implementation IRCIsonQuerySnapshot

- (instancetype)initWithIdentifier:(NSString *)identifier nickname:(NSString *)nickname active:(BOOL)active
{
	NSParameterAssert(identifier != nil);
	NSParameterAssert(nickname != nil);

	if ((self = [super init])) {
		_identifier = [identifier copy];
		_nickname = [nickname copy];
		_active = active;
	}

	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

@end


@implementation IRCIsonApplicationContext

- (instancetype)initWithTrackedUsers:(NSArray<IRCIsonTrackedUserSnapshot *> *)trackedUsers
							 queries:(NSArray<IRCIsonQuerySnapshot *> *)queries
{
	NSParameterAssert(trackedUsers != nil);
	NSParameterAssert(queries != nil);

	if ((self = [super init])) {
		_trackedUsers = [[NSArray alloc] initWithArray:trackedUsers copyItems:YES];
		_queries = [[NSArray alloc] initWithArray:queries copyItems:YES];
	}

	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

@end


@interface IRCIsonTrackedUserChange ()
@property (readwrite, copy) NSString *nickname;
@property (readwrite) IRCIsonTrackedUserChangeKind kind;
- (instancetype)initWithNickname:(NSString *)nickname kind:(IRCIsonTrackedUserChangeKind)kind;
@end

@implementation IRCIsonTrackedUserChange

- (instancetype)initWithNickname:(NSString *)nickname kind:(IRCIsonTrackedUserChangeKind)kind
{
	if ((self = [super init])) {
		_nickname = [nickname copy];
		_kind = kind;
	}

	return self;
}

@end


@interface IRCIsonQueryChange ()
@property (readwrite, copy) NSString *identifier;
@property (readwrite, copy) NSString *nickname;
@property (readwrite, getter=shouldBeActive) BOOL active;
- (instancetype)initWithIdentifier:(NSString *)identifier nickname:(NSString *)nickname active:(BOOL)active;
@end

@implementation IRCIsonQueryChange

- (instancetype)initWithIdentifier:(NSString *)identifier nickname:(NSString *)nickname active:(BOOL)active
{
	if ((self = [super init])) {
		_identifier = [identifier copy];
		_nickname = [nickname copy];
		_active = active;
	}

	return self;
}

@end


@interface IRCIsonApplicationPlan ()
@property (readwrite, copy) NSArray<IRCIsonTrackedUserChange *> *trackedUserChanges;
@property (readwrite, copy) NSArray<IRCIsonQueryChange *> *queryChanges;
- (instancetype)initWithTrackedUserChanges:(NSArray<IRCIsonTrackedUserChange *> *)trackedUserChanges
							 queryChanges:(NSArray<IRCIsonQueryChange *> *)queryChanges;
@end

@implementation IRCIsonApplicationPlan

- (instancetype)initWithTrackedUserChanges:(NSArray<IRCIsonTrackedUserChange *> *)trackedUserChanges
							 queryChanges:(NSArray<IRCIsonQueryChange *> *)queryChanges
{
	if ((self = [super init])) {
		_trackedUserChanges = [trackedUserChanges copy];
		_queryChanges = [queryChanges copy];
	}

	return self;
}

@end


IRCIsonApplicationPlan *IRCIsonApplicationPlanForResult(IRCIsonRoundResult *result, IRCIsonApplicationContext *context)
{
	NSCParameterAssert(result != nil);
	NSCParameterAssert(context != nil);

	IRCIsonRound *round = result.round;
	NSMutableSet<NSString *> *requestedKeys = [NSMutableSet set];
	NSMutableSet<NSString *> *onlineKeys = [NSMutableSet set];

	for (NSString *nickname in round.requestedNicknames) {
		[requestedKeys addObject:IRCNicknameCasefold(nickname, round.caseMapping)];
	}

	for (NSString *nickname in result.onlineNicknames) {
		[onlineKeys addObject:IRCNicknameCasefold(nickname, round.caseMapping)];
	}

	NSMutableArray<IRCIsonTrackedUserChange *> *trackedChanges = [NSMutableArray array];

	for (IRCIsonTrackedUserSnapshot *snapshot in context.trackedUsers) {
		NSString *key = IRCNicknameCasefold(snapshot.nickname, round.caseMapping);

		if ([requestedKeys containsObject:key] == NO) {
			continue;
		}

		BOOL shouldBeOnline = [onlineKeys containsObject:key];

		if (snapshot.isOnline == shouldBeOnline || (round.isInitial && shouldBeOnline == NO)) {
			continue;
		}

		IRCIsonTrackedUserChangeKind kind;

		if (shouldBeOnline) {
			kind = round.isInitial ? IRCIsonTrackedUserChangeKindAvailable : IRCIsonTrackedUserChangeKindSignedOn;
		} else {
			kind = IRCIsonTrackedUserChangeKindSignedOff;
		}

		[trackedChanges addObject:[[IRCIsonTrackedUserChange alloc] initWithNickname:snapshot.nickname kind:kind]];
	}

	NSMutableArray<IRCIsonQueryChange *> *queryChanges = [NSMutableArray array];

	for (IRCIsonQuerySnapshot *snapshot in context.queries) {
		NSString *key = IRCNicknameCasefold(snapshot.nickname, round.caseMapping);

		if ([requestedKeys containsObject:key] == NO) {
			continue;
		}

		BOOL shouldBeActive = [onlineKeys containsObject:key];

		if (snapshot.isActive == shouldBeActive) {
			continue;
		}

		[queryChanges addObject:[[IRCIsonQueryChange alloc] initWithIdentifier:snapshot.identifier
																 nickname:snapshot.nickname
																   active:shouldBeActive]];
	}

	return [[IRCIsonApplicationPlan alloc] initWithTrackedUserChanges:trackedChanges queryChanges:queryChanges];
}
