// YAJLTests YAJLTests.m
//
// Copyright © 2011, Roy Ratcliffe, Pioneering Software, United Kingdom
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS," WITHOUT WARRANTY OF ANY KIND, EITHER
// EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
//------------------------------------------------------------------------------

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
		if (success)
		{
			NSString *string = [generator stringWithError:&error];
			if (string)
			{
				// Note, do not send the re-generated string to the gold string
				// for pass-or-fail comparison. Simple reason is that the
				// generator does not guarantee ordering of keys when generating
				// maps. Ordering is not important for correct operation. You
				// cannot rely on consistent enumeration of keys when iterating
				// a dictionary. Instead log the re-generated JSON to standard
				// error.
				NSLog(@"%@", string);
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
