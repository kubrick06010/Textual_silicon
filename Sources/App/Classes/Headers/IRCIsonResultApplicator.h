#import <Foundation/Foundation.h>

#import "IRCIsonRoundCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IRCIsonTrackedUserChangeKind) {
	IRCIsonTrackedUserChangeKindAvailable,
	IRCIsonTrackedUserChangeKindSignedOn,
	IRCIsonTrackedUserChangeKindSignedOff,
};

@interface IRCIsonTrackedUserSnapshot : NSObject <NSCopying>
@property (readonly, copy) NSString *nickname;
@property (readonly, getter=isOnline) BOOL online;
- (instancetype)initWithNickname:(NSString *)nickname online:(BOOL)online NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface IRCIsonQuerySnapshot : NSObject <NSCopying>
@property (readonly, copy) NSString *identifier;
@property (readonly, copy) NSString *nickname;
@property (readonly, getter=isActive) BOOL active;
- (instancetype)initWithIdentifier:(NSString *)identifier nickname:(NSString *)nickname active:(BOOL)active NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface IRCIsonApplicationContext : NSObject <NSCopying>
@property (readonly, copy) NSArray<IRCIsonTrackedUserSnapshot *> *trackedUsers;
@property (readonly, copy) NSArray<IRCIsonQuerySnapshot *> *queries;
- (instancetype)initWithTrackedUsers:(NSArray<IRCIsonTrackedUserSnapshot *> *)trackedUsers
							 queries:(NSArray<IRCIsonQuerySnapshot *> *)queries NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface IRCIsonTrackedUserChange : NSObject
@property (readonly, copy) NSString *nickname;
@property (readonly) IRCIsonTrackedUserChangeKind kind;
@end

@interface IRCIsonQueryChange : NSObject
@property (readonly, copy) NSString *identifier;
@property (readonly, copy) NSString *nickname;
@property (readonly, getter=shouldBeActive) BOOL active;
@end

@interface IRCIsonApplicationPlan : NSObject
@property (readonly, copy) NSArray<IRCIsonTrackedUserChange *> *trackedUserChanges;
@property (readonly, copy) NSArray<IRCIsonQueryChange *> *queryChanges;
@end

FOUNDATION_EXPORT IRCIsonApplicationPlan *IRCIsonApplicationPlanForResult(
	IRCIsonRoundResult *result,
	IRCIsonApplicationContext *context);

NS_ASSUME_NONNULL_END
