/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */


#import <XCTest/XCTest.h>
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OSInAppMessage.h"
#import "OSTrigger.h"
#import "OSTriggerController.h"
#import "OSInAppMessagingDefines.h"
#import "OSDynamicTriggerController.h"
#import "NSTimerOverrider.h"
#import "UnitTestCommonMethods.h"
#import "OSInAppMessagingHelpers.h"


/**
 Test to make sure that OSInAppMessage correctly
 implements the OSJSONDecodable protocol
 and all properties are parsed correctly
 */

@interface InAppMessagingTests : XCTestCase
@property (strong, nonatomic) OSTriggerController *triggerController;
@end

@implementation InAppMessagingTests {
    OSInAppMessage *testMessage;
}

// called before each test
-(void)setUp {
    [super setUp];
    
    NSTimerOverrider.shouldScheduleTimers = false;
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    testMessage = [OSInAppMessageTestHelper testMessageWithTriggersJson:@[
        @[
            @{
                @"property" : @"view_controller",
                @"operator" : @"==",
                @"value" : @"home_vc"
            }
        ]
    ]];
    
    self.triggerController = [OSTriggerController new];
}

-(void)tearDown {
    NSTimerOverrider.shouldScheduleTimers = true;
}

#pragma mark Message JSON Parsing Tests
- (void)testCorrectlyParsedType {
    XCTAssertTrue(testMessage.type == OSInAppMessageDisplayTypeCenteredModal);
}

-(void)testCorrectlyParsedMessageId {
    XCTAssertTrue([testMessage.messageId isEqualToString:@"a4b3gj7f-d8cc-11e4-bed1-df8f05be55ba"]);
}

-(void)testCorrectlyParsedContentId {
    XCTAssertTrue([testMessage.contentId isEqualToString:@"m8dh7234f-d8cc-11e4-bed1-df8f05be55ba"]);
}

-(void)testCorrectlyParsedTriggers {
    XCTAssertTrue(testMessage.triggers.count == 1);
    XCTAssertEqual(testMessage.triggers.firstObject.firstObject.operatorType, OSTriggerOperatorTypeEqualTo);
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.property, @"view_controller");
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.value, @"home_vc");
}

#pragma mark Message Trigger Logic Tests
-(void)testTriggersWithOneCondition {
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self.triggerController addTriggerWithKey:@"prop1" withValue:@1];
    
    // since the local trigger for prop1 is 1, and the message filter requires >= 2,
    // the message should not match and should evaluate to false
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
}

-(void)testTriggersWithTwoConditions {
    let trigger1 = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeLessThanOrEqualTo withValue:@-3];
    let trigger2 = [OSTrigger triggerWithProperty:@"prop2" withOperator:OSTriggerOperatorTypeEqualTo withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger1, trigger2]]];
    
    [self.triggerController addTriggers:@{
        @"prop1" : @-4.3,
        @"prop2" : @2
    }];
    
    // Both triggers should evaluate to true
    XCTAssertTrue([self.triggerController messageMatchesTriggers:message]);
}

-(void)testTriggersWithOrCondition {
    let trigger1 = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeLessThanOrEqualTo withValue:@-3];
    let trigger2 = [OSTrigger triggerWithProperty:@"prop2" withOperator:OSTriggerOperatorTypeEqualTo withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger1], @[trigger2]]];
    
    // The first trigger should evaluate to false, but since the first level array
    // represents OR conditions and the second trigger array evaluates to true,
    // the whole result should be true
    [self.triggerController addTriggers:@{
        @"prop1" : @7.3,
        @"prop2" : @2
    }];
    
    XCTAssertTrue([self.triggerController messageMatchesTriggers:message]);
}

-(void)testTriggerWithMissingValue {
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    // the trigger controller will have no value for 'prop1'
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
}

- (void)testExistsOperator {
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeExists withValue:nil];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    // the property 'prop1' has not been set on local triggers, so the
    // Exists operator should return false
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
    
    [self.triggerController addTriggerWithKey:@"prop1" withValue:@"test"];
    
    // Now that we have set a value for 'prop1', the check should return true
    XCTAssertTrue([self.triggerController messageMatchesTriggers:message]);
}

- (void)testNotEqualToOperator {
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeNotEqualTo withValue:@3];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self.triggerController addTriggerWithKey:@"prop1" withValue:@2];
    
    XCTAssertTrue([self.triggerController messageMatchesTriggers:message]);
    
    [self.triggerController addTriggerWithKey:@"prop1" withValue:@3];
    
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
}

- (BOOL)setupComparativeOperatorTest:(OSTriggerOperatorType)operator withTrigger:(id)triggerValue withLocalValue:(id)localValue {
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:operator withValue:triggerValue];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self.triggerController addTriggerWithKey:@"prop1" withValue:localValue];
    
    return [self.triggerController messageMatchesTriggers:message];
}

- (void)testGreaterThan {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThan withTrigger:@3 withLocalValue:@3.1]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThan withTrigger:@2.1 withLocalValue:@2]);
}

- (void)testGreaterThanOrEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTrigger:@3 withLocalValue:@3]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTrigger:@2 withLocalValue:@2.9]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTrigger:@5 withLocalValue:@4]);
}

- (void)testEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTrigger:@0.1 withLocalValue:@0.1]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTrigger:@0.0 withLocalValue:@2]);
}

- (void)testLessThan {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTrigger:@2 withLocalValue:@1.9]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTrigger:@3 withLocalValue:@4]);
}

- (void)testLessThanOrEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTrigger:@5 withLocalValue:@4]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTrigger:@3 withLocalValue:@3]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTrigger:@3 withLocalValue:@4]);
}

- (void)testInvalidOperator {
    let triggerJson = @{
        @"property" : @"prop1",
        @"operator" : @"<<<",
        @"value" : @2
    };
    
    // When invalid JSON is encountered, the in-app message should
    // not initialize and should return nil
    XCTAssertNil([OSInAppMessageTestHelper testMessageWithTriggersJson:@[@[triggerJson]]]);
}

- (void)testNumericContainsOperator {
    let localArray = @[@1, @2, @3];
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeContains withTrigger:@2 withLocalValue:localArray]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeContains withTrigger:@4 withLocalValue:localArray]);
}

- (void)testStringContainsOperator {
    let localArray = @[@"test1", @"test2", @"test3"];
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeContains withTrigger:@"test2" withLocalValue:localArray]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeContains withTrigger:@"test5" withLocalValue:localArray]);
}

// Tests the macro that gets the Display Type's equivalent OSInAppMessageDisplayPosition
- (void)testDisplayTypeConversion {
    let top = OS_DISPLAY_POSITION_FOR_TYPE(OSInAppMessageDisplayTypeTopBanner);
    let bottom = OS_DISPLAY_POSITION_FOR_TYPE(OSInAppMessageDisplayTypeBottomBanner);
    let modal = OS_DISPLAY_POSITION_FOR_TYPE(OSInAppMessageDisplayTypeCenteredModal);
    let full = OS_DISPLAY_POSITION_FOR_TYPE(OSInAppMessageDisplayTypeFullScreen);
    
    XCTAssertTrue(top == OSInAppMessageDisplayPositionTop);
    XCTAssertTrue(bottom == OSInAppMessageDisplayPositionBottom);
    XCTAssertTrue(modal == OSInAppMessageDisplayPositionCentered);
    XCTAssertTrue(full == OSInAppMessageDisplayPositionCentered);
}

// Tests the macro to convert strings to OSInAppMessageDisplayType
- (void)testStringToDisplayTypeConversion {
    let top = OS_DISPLAY_TYPE_FOR_STRING(@"top_banner");
    let bottom = OS_DISPLAY_TYPE_FOR_STRING(@"bottom_banner");
    let modal = OS_DISPLAY_TYPE_FOR_STRING(@"centered_modal");
    let full = OS_DISPLAY_TYPE_FOR_STRING(@"full_screen");
    
    XCTAssertTrue(top == OSInAppMessageDisplayTypeTopBanner);
    XCTAssertTrue(bottom == OSInAppMessageDisplayTypeBottomBanner);
    XCTAssertTrue(modal == OSInAppMessageDisplayTypeCenteredModal);
    XCTAssertTrue(full == OSInAppMessageDisplayTypeFullScreen);
}

- (void)testDynamicTriggerWithExactTimeTrigger {
    let trigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@([[NSDate date] timeIntervalSince1970])];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];

    XCTAssertTrue(triggered);
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
}

- (void)testDynamicTriggerSchedulesExactTimeTrigger {
    let trigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@([[NSDate date] timeIntervalSince1970] + 5.0f)];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];

    XCTAssertFalse(triggered);
    XCTAssertTrue(roughlyEqualDoubles(NSTimerOverrider.mostRecentTimerInterval, 5.0f));
}

// Ensure that the Exact Time trigger will not fire after the date has passed
- (void)testDynamicTriggerDoesntTriggerPastTime {
    let trigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@([[NSDate date] timeIntervalSince1970] - 5.0f)];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];

    XCTAssertFalse(triggered);
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
}

// The session duration trigger is set to fire in 30 seconds into the session
- (void)testDynamicTriggerSessionDurationLaunchesTimer {
    let trigger = [OSTrigger triggerWithProperty:OS_SESSION_DURATION_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@30];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];
    
    XCTAssertFalse(triggered);
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
    XCTAssertTrue(fabs(NSTimerOverrider.mostRecentTimerInterval - 30.0f) < 0.1f);
}

- (void)testDynamicTriggerSDKVersion {
    let trigger = [OSTrigger triggerWithProperty:OS_SDK_VERSION_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:OS_SDK_VERSION];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];
    
    XCTAssertTrue(triggered);
}

@end

