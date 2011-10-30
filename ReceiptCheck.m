//
//  ReceiptCheck.m
//  Newsstand
//
//  Created by Carlo Vigiani on 29/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import "ReceiptCheck.h"
#import "NSString+Base64.h"

#warning INSERT YOUR ITUNESCONNECT SHARED SECRET
#define SHARED_SECRET @"INSERT HERE YOUR ITUNESCONNECT SHARED SECRECT KEY FOR AUTORENEWABLE SUBCRIPTIONS RECEIPT VALIDATION"

@implementation ReceiptCheck

@synthesize receiptData,completionBlock;

+(ReceiptCheck *)validateReceiptWithData:(NSData *)_receiptData completionHandler:(void(^)(BOOL,NSString *))handler {
    ReceiptCheck *checker = [[ReceiptCheck alloc] init];
    checker.receiptData=_receiptData;
    checker.completionBlock=handler;
    [checker checkReceipt];
    return checker;
    
}

-(void)checkReceipt {
    // verifies receipt with Apple
    NSError *jsonError = nil;
    NSString *receiptBase64 = [NSString base64StringFromData:receiptData length:[receiptData length]];
    NSLog(@"Receipt Base64: %@",receiptBase64);
    //NSString *jsonRequest=[NSString stringWithFormat:@"{\"receipt-data\":\"%@\"}",receiptBase64];
    //NSLog(@"Sending this JSON: %@",jsonRequest);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                receiptBase64,@"receipt-data",
                                                                SHARED_SECRET,@"password",
                                                                nil]
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&jsonError
                        ];
    NSLog(@"JSON: %@",[[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] autorelease]);
    // URL for sandbox receipt validation; replace "sandbox" with "buy" in production or you will receive
    // error codes 21006 or 21007
    NSURL *requestURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:requestURL];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:jsonData];
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:req delegate:self];
    if(conn) {
        receivedData = [[NSMutableData alloc] init];
    } else {
        completionBlock(NO,@"Cannot create connection");
        [self autorelease];
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Cannot transmit receipt data. %@",[error localizedDescription]);
    completionBlock(NO,[error localizedDescription]);
    [self autorelease];
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [receivedData setLength:0];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [receivedData appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *response = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    NSLog(@"iTunes response: %@",response);
    completionBlock(YES,response);
    [self autorelease];
}


@end
