//
//  Publisher.m
//  Newsstand
//
//  Created by Carlo Vigiani on 18/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import "Publisher.h"
#import <NewsstandKit/NewsstandKit.h>

NSString *PublisherDidUpdateNotification = @"PublisherDidUpdate";
NSString *PublisherFailedUpdateNotification = @"PublisherFailedUpdate";

@interface Publisher ()



@end

@implementation Publisher 

@synthesize ready;

-(id)init {
    self = [super init];
    if(self) {
        ready = NO;
        issues = nil;
    }
    return self;
}

-(void)dealloc {
    [issues release];
    [super dealloc];
}

-(void)getIssuesList {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
                   ^{
                       NSArray *tmpIssues = [NSArray arrayWithContentsOfURL:[NSURL URLWithString:@"http://www.viggiosoft.com/media/data/blog/newsstand/issues.plist"]];
                       if(!tmpIssues) {
                           dispatch_async(dispatch_get_main_queue(), ^{
                               [[NSNotificationCenter defaultCenter] postNotificationName:PublisherFailedUpdateNotification object:self];
                           });
                          
                       } else {
                           if(issues) {
                               [issues release];
                           }
                           issues = [[NSArray alloc] initWithArray:tmpIssues];
                           ready = YES;
                           [self addIssuesInNewsstand];
                           NSLog(@"%@",issues);
                           dispatch_async(dispatch_get_main_queue(), ^{
                               [[NSNotificationCenter defaultCenter] postNotificationName:PublisherDidUpdateNotification object:self];
                           });
                       }
                   });
}

-(void)addIssuesInNewsstand {
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    [issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *name = [(NSDictionary *)obj objectForKey:@"Name"];
        NKIssue *nkIssue = [nkLib issueWithName:name];
        if(!nkIssue) {
            nkIssue = [nkLib addIssueWithName:name date:[(NSDictionary *)obj objectForKey:@"Date"]];
        }
        NSLog(@"Issue: %@",nkIssue);
    }];
}

-(NSInteger)numberOfIssues {
    if([self isReady] && issues) {
        return [issues count];
    } else {
        return 0;
    }
}

-(NSDictionary *)issueAtIndex:(NSInteger)index {
    return [issues objectAtIndex:index];
}

-(NSString *)titleOfIssueAtIndex:(NSInteger)index {
    return [[self issueAtIndex:index] objectForKey:@"Title"];
}

-(NSString *)nameOfIssueAtIndex:(NSInteger)index {
   return [[self issueAtIndex:index] objectForKey:@"Name"];    
}

-(void)setCoverOfIssueAtIndex:(NSInteger)index  completionBlock:(void(^)(UIImage *img))block {
    NSURL *coverURL = [NSURL URLWithString:[[self issueAtIndex:index] objectForKey:@"Cover"]];
    NSString *coverFileName = [coverURL lastPathComponent];
    NSString *coverFilePath = [CacheDirectory stringByAppendingPathComponent:coverFileName];
    UIImage *image = [UIImage imageWithContentsOfFile:coverFilePath];
    if(image) {
        block(image);
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                       ^{
                           NSData *imageData = [NSData dataWithContentsOfURL:coverURL];
                           UIImage *image = [UIImage imageWithData:imageData];
                           if(image) {
                               [imageData writeToFile:coverFilePath atomically:YES];
                               block(image);
                           }
                       });
    }
}

-(UIImage *)coverImageForIssue:(NKIssue *)nkIssue {
    NSString *name = nkIssue.name;
    for(NSDictionary *issueInfo in issues) {
        if([name isEqualToString:[issueInfo objectForKey:@"Name"]]) {
            NSString *coverPath = [issueInfo objectForKey:@"Cover"];
            NSString *coverName = [coverPath lastPathComponent];
            NSString *coverFilePath = [CacheDirectory stringByAppendingPathComponent:coverName];
            UIImage *image = [UIImage imageWithContentsOfFile:coverFilePath];
            return image;
        }
    }
    return nil;
}

-(NSURL *)contentURLForIssueWithName:(NSString *)name {
    __block NSURL *contentURL=nil;
    [issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *aName = [(NSDictionary *)obj objectForKey:@"Name"];
        if([aName isEqualToString:name]) {
            contentURL = [[NSURL URLWithString:[(NSDictionary *)obj objectForKey:@"Content"]] retain];
            *stop=YES;
        }
    }];
    NSLog(@"Content URL for issue with name %@ is %@",name,contentURL);
    return [contentURL autorelease];
}

-(NSString *)downloadPathForIssue:(NKIssue *)nkIssue {
    return [[nkIssue.contentURL path] stringByAppendingPathComponent:@"magazine.pdf"];
}

@end
