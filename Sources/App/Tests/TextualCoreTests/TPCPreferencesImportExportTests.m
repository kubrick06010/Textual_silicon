@import XCTest;

#import "IRCClientConfig.h"
#import "IRCServer.h"
#import "IRCWorld.h"
#import "TPCPreferencesImportExportPrivate.h"

@interface TPCPreferencesImportExportTests : XCTestCase
@end

@implementation TPCPreferencesImportExportTests

- (NSDictionary<NSString *, id> *)textualSevenTwoSevenClientConfiguration
{
	return @{
		@"dictionaryVersion" : @710,
		@"uniqueIdentifier" : @"client-7-2-7",
		@"connectionName" : @"Example Network",
		@"nickname" : @"ExampleNick",
		@"username" : @"example-user",
		@"realName" : @"Example User",
		@"autoConnect" : @YES,
		@"autoReconnect" : @YES,
		@"serverList" : @[
			@{
				@"uniqueIdentifier" : @"server-7-2-7",
				@"serverAddress" : @"irc.example.test",
				@"serverPort" : @6697,
				@"prefersSecuredConnection" : @YES
			}
		]
	};
}

- (void)testAcceptsDirectSevenTwoSevenClientListAndPreservesConnectionData
{
	NSDictionary<NSString *, id> *clientConfiguration = [self textualSevenTwoSevenClientConfiguration];

	NSArray<NSDictionary<NSString *, id> *> *result =
	[TPCPreferencesImportExport clientConfigurationsFromImportObject:@[clientConfiguration]];

	XCTAssertEqual(result.count, 1U);
	XCTAssertEqualObjects(result.firstObject, clientConfiguration);

	IRCClientConfig *importedConfiguration =
	[[IRCClientConfig alloc] initWithDictionary:result.firstObject];
	IRCServer *importedServer = importedConfiguration.serverList.firstObject;

	XCTAssertEqualObjects(importedConfiguration.uniqueIdentifier, @"client-7-2-7");
	XCTAssertEqualObjects(importedConfiguration.connectionName, @"Example Network");
	XCTAssertTrue(importedConfiguration.autoConnect);
	XCTAssertTrue(importedConfiguration.autoReconnect);
	XCTAssertEqual(importedConfiguration.serverList.count, 1U);
	XCTAssertEqualObjects(importedServer.serverAddress, @"irc.example.test");
	XCTAssertEqual(importedServer.serverPort, (uint16_t)6697);
	XCTAssertTrue(importedServer.prefersSecuredConnection);
}

- (void)testAcceptsLegacyWorldControllerWrapperWithoutChangingClientData
{
	NSDictionary<NSString *, id> *clientConfiguration = [self textualSevenTwoSevenClientConfiguration];
	NSDictionary *legacyWorldControllerObject = @{ @"clients" : @[clientConfiguration] };

	NSArray<NSDictionary<NSString *, id> *> *result =
	[TPCPreferencesImportExport clientConfigurationsFromImportObject:legacyWorldControllerObject];

	XCTAssertEqual(result.count, 1U);
	XCTAssertEqualObjects(result.firstObject, clientConfiguration);
}

- (void)testRejectsMalformedClientListsWithoutDroppingAValidListPartially
{
	NSDictionary<NSString *, id> *clientConfiguration = [self textualSevenTwoSevenClientConfiguration];
	NSArray *malformedDirectList = @[clientConfiguration, @"not-a-dictionary"];
	NSDictionary *malformedLegacyList = @{ @"clients" : @[@"not-a-dictionary"] };

	XCTAssertNil([TPCPreferencesImportExport clientConfigurationsFromImportObject:malformedDirectList]);
	XCTAssertNil([TPCPreferencesImportExport clientConfigurationsFromImportObject:malformedLegacyList]);
	XCTAssertNil([TPCPreferencesImportExport clientConfigurationsFromImportObject:@"not-a-client-list"]);
	XCTAssertEqual([TPCPreferencesImportExport clientConfigurationsFromImportObject:@[]].count, 0U);
}

@end
