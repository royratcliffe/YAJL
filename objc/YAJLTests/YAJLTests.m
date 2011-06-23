//
//  YAJLTests.m
//  YAJLTests
//
//  Created by Roy Ratcliffe on 17/06/2011.
//  Copyright 2011 Pioneering Software, United Kingdom. All rights reserved.
//

#import "YAJLTests.h"
#import "YAJLParser.h"
#import "YAJLGenerator.h"

@interface YAJLTestCase : SenTestCase
{
@private
	NSString *testCasePath;
}

@property(retain, NS_NONATOMIC_IPHONEONLY) NSString *testCasePath;

@end

@implementation YAJLTestCase

@synthesize testCasePath;

- (void)passOrFail
{
	NSMutableString *goldString = [NSMutableString string];
	[goldString appendFormat:@"TEST CASE %@\n", [testCasePath lastPathComponent]];
	NSError *error = nil;
	NSData *JSONData = [NSData dataWithContentsOfFile:testCasePath options:NSDataReadingMapped error:&error];
	NSString *JSONString = [[[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding] autorelease];
	[goldString appendFormat:@"\nJSON\n----\n%@", JSONString];
	
	YAJLParser *parser = [[[YAJLParser alloc] init] autorelease];
	if ([[testCasePath lastPathComponent] hasPrefix:@"ac_"])
	{
		[parser setAllowComments:YES];
	}
	if ([[testCasePath lastPathComponent] hasPrefix:@"ag_"])
	{
		[parser setAllowTrailingGarbage:YES];
	}
	if ([[testCasePath lastPathComponent] hasPrefix:@"am_"])
	{
		[parser setAllowMultipleValues:YES];
	}
	if ([[testCasePath lastPathComponent] hasPrefix:@"ap_"])
	{
		[parser setAllowPartialValues:YES];
	}
	BOOL success = [parser parseData:JSONData error:&error] && [parser completeParseWithError:&error];
	[goldString appendFormat:@"\nPARSE\n-----\n%@\n", success ? @"success" : @"failure"];
	if (success)
	{
		YAJLGenerator *generator = [[[YAJLGenerator alloc] init] autorelease];
		success = [generator generateObject:[parser rootObject] error:&error];
		[goldString appendFormat:@"\nRE-GENERATE\n-- --------\n%@\n", success ? @"success" : @"failure"];
		if (success)
		{
			NSString *string = [generator stringWithError:&error];
			if (string)
			{
				[goldString appendFormat:@"%@\n", string];
			}
			else
			{
				[goldString appendFormat:@"error: %@\n", [error localizedDescription]];
			}
		}
	}
	else
	{
		[goldString appendFormat:@"error: %@\n", [error localizedDescription]];
	}
	
	NSString *currentDirectoryPath = [[NSFileManager defaultManager] currentDirectoryPath];
	NSString *YAJLTestsPath = [[currentDirectoryPath stringByAppendingPathComponent:@"../YAJLTests"] stringByStandardizingPath];
	NSString *goldPath = [YAJLTestsPath stringByAppendingPathComponent:[[[testCasePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"gold"]];
	if ([[NSFileManager defaultManager] fileExistsAtPath:goldPath])
	{
		NSData *goldData = [[NSFileManager defaultManager] contentsAtPath:goldPath];
		STAssertEqualObjects([[[NSString alloc] initWithData:goldData encoding:NSUTF8StringEncoding] autorelease], goldString, nil);
	}
	else
	{
		[[NSFileManager defaultManager] createFileAtPath:goldPath contents:[goldString dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
	}
}

@end

@implementation YAJLTests

- (void)setUp
{
	testCases = [[NSMutableArray alloc] init];
	NSString *currentDirectoryPath = [[NSFileManager defaultManager] currentDirectoryPath];
	NSString *testCasesPath = [[currentDirectoryPath stringByAppendingPathComponent:@"../../test/cases"] stringByStandardizingPath];
	NSError *error = nil;
	for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:testCasesPath error:&error])
	{
		NSString *pathExtension = [fileName pathExtension];
		if ([pathExtension isEqualToString:@"json"])
		{
			YAJLTestCase *testCase = [YAJLTestCase testCaseWithSelector:@selector(passOrFail)];
			[testCase setTestCasePath:[testCasesPath stringByAppendingPathComponent:fileName]];
			[testCases addObject:testCase];
		}
	}
}

- (void)tearDown
{
	[testCases release];
}

- (void)testCases
{
	for (YAJLTestCase *testCase in testCases)
	{
		[testCase run];
	}
}

@end
