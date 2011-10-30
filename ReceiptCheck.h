//
//  ReceiptCheck.h
//  Newsstand
//
//  Created by Carlo Vigiani on 29/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ReceiptCheck : NSObject<NSURLConnectionDelegate> {
    NSMutableData *receivedData;
}

+(ReceiptCheck *)validateReceiptWithData:(NSData *)receiptData completionHandler:(void(^)(BOOL,NSString *))handler;

@property (nonatomic,retain) void(^completionBlock)(BOOL,NSString *);
@property (nonatomic,retain) NSData *receiptData;

-(void)checkReceipt;

@end
