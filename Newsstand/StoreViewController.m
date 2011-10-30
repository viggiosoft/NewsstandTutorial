//
//  StoreViewController.m
//  Newsstand
//
//  Created by Carlo Vigiani on 17/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import "StoreViewController.h"
#import "ReceiptCheck.h"


@interface StoreViewController (Private)

-(void)showIssues;
-(void)loadIssues;
-(void)readIssue:(NKIssue *)nkIssue;
-(void)downloadIssueAtIndex:(NSInteger)index;

-(void)errorWithTransaction:(SKPaymentTransaction *)transaction;
-(void)finishedTransaction:(SKPaymentTransaction *)transaction;
-(void)checkReceipt:(NSData *)receipt;

- (NSString *)decodeBase64:(NSString *)input;

@end

@implementation StoreViewController
@synthesize table=table_;
@synthesize issueCell;
@synthesize purchasing=purchasing_;

static NSString *issueTableCellId = @"IssueTableCell";

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        publisher = [[Publisher alloc] init];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    // define right bar button items
    refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(loadIssues)];
    UIActivityIndicatorView *loadingActivity = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
    [loadingActivity startAnimating];
    waitButton = [[UIBarButtonItem alloc] initWithCustomView:loadingActivity];
    [waitButton setTarget:nil];
    [waitButton setAction:nil];
    
    // left bar button item
    self.navigationItem.leftBarButtonItem=[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(trashContent)] autorelease];
    
    // table
    [table_ registerNib:[UINib nibWithNibName:@"IssueTableCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:issueTableCellId];
    
    
    if([publisher isReady]) {
        [self showIssues];
    } else {
        [self loadIssues];
    }
}

- (void)viewDidUnload
{
    [self setTable:nil];
    [self setIssueCell:nil];
    [super viewDidUnload];
    [waitButton release];
    [refreshButton release];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)dealloc {
    [table_ release];
    [issueCell release];
    [super dealloc];
}

#pragma mark - Publisher interaction

-(void)loadIssues {
    table_.alpha=0.0;
    [self.navigationItem setRightBarButtonItem:waitButton];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:PublisherDidUpdateNotification object:publisher];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherFailed:) name:PublisherFailedUpdateNotification object:publisher];
    [publisher getIssuesList];    
}

-(void)publisherReady:(NSNotification *)not {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:publisher];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:publisher];
    [self showIssues];
}

-(void)showIssues {
    [self.navigationItem setRightBarButtonItem:refreshButton];
    table_.alpha=1.0;
    [table_ reloadData];
}

-(void)publisherFailed:(NSNotification *)not {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:publisher];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:publisher];
    NSLog(@"%@",not);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:@"Cannot get issues from publisher server."
                                                   delegate:nil
                                          cancelButtonTitle:@"Close"
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
    [self.navigationItem setRightBarButtonItem:refreshButton];    
}

#pragma mark - UITableView

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [publisher numberOfIssues];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:issueTableCellId];
    NSLog(@"%@",cell);
    NSInteger index = indexPath.row;
    UILabel *titleLabel = (UILabel *)[cell viewWithTag:101];
    titleLabel.text=[publisher titleOfIssueAtIndex:index];
    UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
    imageView.image=nil; // reset image as it will be retrieved asychronously
    [publisher setCoverOfIssueAtIndex:index completionBlock:^(UIImage *img) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [table_ cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:0]];
            UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
            imageView.image=img;
        });
    }];
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    NKIssue *nkIssue = [nkLib issueWithName:[publisher nameOfIssueAtIndex:index]];
    UIProgressView *downloadProgress = (UIProgressView *)[cell viewWithTag:102];
    UILabel *tapLabel = (UILabel *)[cell viewWithTag:103];
    if(nkIssue.status==NKIssueContentStatusAvailable) {
        tapLabel.text=@"TAP TO READ";
        tapLabel.alpha=1.0;
        downloadProgress.alpha=0.0;
    } else {
        if(nkIssue.status==NKIssueContentStatusDownloading) {
            downloadProgress.alpha=1.0;
            tapLabel.alpha=0.0;
        } else {
            downloadProgress.alpha=0.0;
            tapLabel.alpha=1.0;
            tapLabel.text=@"TAP TO DOWNLOAD";
        }
        
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // possible actions: read or download
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    NKIssue *nkIssue = [nkLib issueWithName:[publisher nameOfIssueAtIndex:indexPath.row]];
   // NSURL *downloadURL = [nkIssue contentURL];
    if(nkIssue.status==NKIssueContentStatusAvailable) {
        [self readIssue:nkIssue];
    } else if(nkIssue.status==NKIssueContentStatusNone) {
        [self downloadIssueAtIndex:indexPath.row];
    }
}

#pragma mark - Issue actions

-(void)readIssue:(NKIssue *)nkIssue {
    [[NKLibrary sharedLibrary] setCurrentlyReadingIssue:nkIssue];
    QLPreviewController *previewController = [[[QLPreviewController alloc] init] autorelease];
    previewController.delegate=self;
    previewController.dataSource=self;
    [self presentModalViewController:previewController animated:YES];
}

-(void)downloadIssueAtIndex:(NSInteger)index {
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    NKIssue *nkIssue = [nkLib issueWithName:[publisher nameOfIssueAtIndex:index]];    
    NSURL *downloadURL = [publisher contentURLForIssueWithName:nkIssue.name];
    if(!downloadURL) return;
    NSURLRequest *req = [NSURLRequest requestWithURL:downloadURL];
    NKAssetDownload *assetDownload = [nkIssue addAssetWithRequest:req];
    [assetDownload downloadWithDelegate:self];
    [assetDownload setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInt:index],@"Index",
                                nil]];
    
}

#pragma mark - NSURLConnectionDownloadDelegate

-(void)updateProgressOfConnection:(NSURLConnection *)connection withTotalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long)expectedTotalBytes {
    // get asset
    NKAssetDownload *dnl = connection.newsstandAssetDownload;
    UITableViewCell *cell = [table_ cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[[dnl.userInfo objectForKey:@"Index"] intValue] inSection:0]];
    UIProgressView *progressView = (UIProgressView *)[cell viewWithTag:102];
    progressView.alpha=1.0;
    [[cell viewWithTag:103] setAlpha:0.0];
    progressView.progress=1.f*totalBytesWritten/expectedTotalBytes;   
}

-(void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long)expectedTotalBytes {
    [self updateProgressOfConnection:connection withTotalBytesWritten:totalBytesWritten expectedTotalBytes:expectedTotalBytes];
}

-(void)connectionDidResumeDownloading:(NSURLConnection *)connection totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long)expectedTotalBytes {
    NSLog(@"Resume downloading %f",1.f*totalBytesWritten/expectedTotalBytes);
    [self updateProgressOfConnection:connection withTotalBytesWritten:totalBytesWritten expectedTotalBytes:expectedTotalBytes];    
}

-(void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL {
    // copy file to destination URL
    NKAssetDownload *dnl = connection.newsstandAssetDownload;
    NKIssue *nkIssue = dnl.issue;
    NSString *contentPath = [publisher downloadPathForIssue:nkIssue];
    NSError *moveError=nil;
    NSLog(@"File is being copied to %@",contentPath);
    
    if([[NSFileManager defaultManager] moveItemAtPath:[destinationURL path] toPath:contentPath error:&moveError]==NO) {
        NSLog(@"Error copying file from %@ to %@",destinationURL,contentPath);
    }
    
    // update the Newsstand icon
    UIImage *img = [publisher coverImageForIssue:nkIssue];
    if(img) {
        [[UIApplication sharedApplication] setNewsstandIconImage:img]; 
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
    }
    
    [table_ reloadData];
}



#pragma mark - QuickLook

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller {
    return 1;
}

- (id <QLPreviewItem>) previewController: (QLPreviewController *) controller previewItemAtIndex: (NSInteger) index {
    NKIssue *nkIssue = [[NKLibrary sharedLibrary] currentlyReadingIssue];
    NSURL *issueURL = [NSURL fileURLWithPath:[publisher downloadPathForIssue:nkIssue]];
    NSLog(@"Issue URL: %@",issueURL);
    return issueURL;
}

#pragma mark - Trash content

// remove all downloaded magazines
-(void)trashContent {
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    NSLog(@"%@",nkLib.issues);
    [nkLib.issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [nkLib removeIssue:(NKIssue *)obj];
    }];
    [publisher addIssuesInNewsstand];
    [table_ reloadData];
}

#pragma mark StoreKit

- (IBAction)subscription:(NSString *)productId {
    if(purchasing_==YES) {
        return;
    }
    purchasing_=YES;
    // product request
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:productId]];
    productsRequest.delegate=self;
    [productsRequest start];
}

// 1 month subscription button callback
- (IBAction)paid1Month:(id)sender {
    [self subscription:@"com.viggiosoft.tutorial.NewsstandTutorial.1month"];
}


// 1year subscription button callback
- (IBAction)paid1Year:(id)sender {
    [self subscription:@"com.viggiosoft.tutorial.NewsstandTutorial.1year"];
}


// "free subscription" button callback
- (IBAction)freeSubscription:(id)sender {
   [self subscription:@"com.viggiosoft.tutorial.NewsstandTutorial.001"];
}

-(void)requestDidFinish:(SKRequest *)request {
    purchasing_=NO;
    NSLog(@"Request: %@",request);
}

-(void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    purchasing_=NO;
    NSLog(@"Request %@ failed with error %@",request,error);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Purchase error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
    [alert show];
    [alert release];
}

-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSLog(@"Request: %@ -- Response: %@",request,response);
    NSLog(@"Products: %@",response.products);
    for(SKProduct *product in response.products) {
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}



-(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for(SKPaymentTransaction *transaction in transactions) {
        NSLog(@"Updated transaction %@",transaction);
        switch (transaction.transactionState) {
            case SKPaymentTransactionStateFailed:
                [self errorWithTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"Purchasing...");
                break;
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateRestored:
                [self finishedTransaction:transaction];
                break;
            default:
                break;
        }
    }
}

-(void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"Restored all completed transactions");
}

-(void)finishedTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"Finished transaction");
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    /*
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subscription done"
                                                    message:[NSString stringWithFormat:@"Receipt to be sent: %@\nTransaction ID: %@",transaction.transactionReceipt,transaction.transactionIdentifier]
                                                   delegate:nil
                                          cancelButtonTitle:@"Close"
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
    */
    // save receipt
    [[NSUserDefaults standardUserDefaults] setObject:transaction.transactionIdentifier forKey:@"receipt"];
    // check receipt
    [self checkReceipt:transaction.transactionReceipt];
}

-(void)errorWithTransaction:(SKPaymentTransaction *)transaction {
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subscription failure"
                                                    message:[transaction.error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"Close"
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

-(void)checkReceipt:(NSData *)receipt {
    // save receipt
    NSString *receiptStorageFile = [DocumentsDirectory stringByAppendingPathComponent:@"receipts.plist"];
    NSMutableArray *receiptStorage = [[NSMutableArray alloc] initWithContentsOfFile:receiptStorageFile];
    if(!receiptStorage) {
        receiptStorage = [[NSMutableArray alloc] init];
    }
    [receiptStorage addObject:receipt];
    [receiptStorage writeToFile:receiptStorageFile atomically:YES];
    [receiptStorage release];
    [ReceiptCheck validateReceiptWithData:receipt completionHandler:^(BOOL success,NSString *answer){
        if(success==YES) {
            NSLog(@"Receipt has been validated: %@",answer);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Purchase OK" message:nil delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
            [alert show];
            [alert release];
        } else {
            NSLog(@"Receipt not validated! Error: %@",answer);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Purchase Error" message:@"Cannot validate receipt" delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
            [alert show];
            [alert release];
        };
    }];
}

#pragma mark - Check all saved receipts

-(void)checkReceipts:(id)sender {
    // open receipts
    NSArray *receipts = [[[NSArray alloc] initWithContentsOfFile:[DocumentsDirectory stringByAppendingPathComponent:@"receipts.plist"]] autorelease];
    if(!receipts || [receipts count]==0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No receipts" message:nil delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
        [alert show];
        [alert release];
        return;
    }
    for(NSData *aReceipt in receipts) {
        [ReceiptCheck validateReceiptWithData:aReceipt completionHandler:^(BOOL success, NSString *message) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Receipt validation"
                                       message:[NSString stringWithFormat:@"Success:%d - Message:%@",success,message]
                                                                 delegate:nil
                                                        cancelButtonTitle:@"Close"
                                                        otherButtonTitles:nil];
            [alert show];
            [alert release];
        }
         ];
    }
}
                            

@end
