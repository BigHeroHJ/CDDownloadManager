//
//  CDownLoadManager.m
//  CDownLoadManager
//
//  Created by Lemon HOLL on 2016/12/8.
//  Copyright © 2016年 Lemon HOLL. All rights reserved.
//

#import "CDownLoadManager.h"

#import "CDownLoadReceipItem.h"
#import "MD5String.h"
#import "AFNetworking.h"

@interface CDownLoadManager()<NSURLSessionDataDelegate,NSURLSessionDelegate>



@property (nonatomic, strong) NSURLSession *session; // 管理下载的session
@property (nonatomic, strong) dispatch_queue_t synchromizationQueue;//这个Manager 进行所有任务下载操作的队列

@property (nonatomic, assign) NSInteger maxNumActiveDownloads;//最大活跃的下载数。 未实现
@property (nonatomic, assign) NSUInteger activeReqestCount;

@property (nonatomic, strong) NSMutableArray *queuedTasks;
@property (nonatomic, strong) NSMutableDictionary *tasks;

@property (nonatomic, strong) NSMutableDictionary *allDownloadReceipts;

@end


@implementation CDownLoadManager

- (NSMutableDictionary *)allDownloadReceipts
{
    if (_allDownloadReceipts == nil) {
        _allDownloadReceipts = [NSMutableDictionary dictionary];
    }
    
    return _allDownloadReceipts;
}



+ (instancetype)shareInstance
{
    static CDownLoadManager *downloadManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloadManager = [[self alloc] init];
    });
    
    return downloadManager;
    
}
+ (NSURLSessionConfiguration *)defaultURLSessionConfiguration {
    //注意点 别用alloc init 
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    configuration.HTTPShouldSetCookies = YES;
    configuration.HTTPShouldUsePipelining = NO;
    configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
    configuration.allowsCellularAccess = YES;
    configuration.timeoutIntervalForRequest = 10.0;
    configuration.HTTPMaximumConnectionsPerHost = 10;
    return configuration;
}
- (instancetype)init
{
    //一些配置
    NSURLSessionConfiguration *sessionConfig = [CDownLoadManager defaultURLSessionConfiguration];//默认配置
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:queue];

    return [self initWithSession:session downloadPrioritization:CDownLoadManagerPrioritizeFIFO maximumActiveDownloads:4];
    
}

- (instancetype)initWithSession:(NSURLSession *)session downloadPrioritization:(CDownLoadManagerPrioritize)downloadPrioritization maximumActiveDownloads:(NSInteger)maximumActiveDownloads
{
    self.session = session;
    self.maxNumActiveDownloads = maximumActiveDownloads;
    self.downloadPrioritize = downloadPrioritization;
    
    //在初始化manager的时候 初始化对应的session queue 和一些数组，字典
    self.queuedTasks = [[NSMutableArray alloc] init];
    self.tasks = [[NSMutableDictionary alloc] init];
    
    self.activeReqestCount = 0;//初始化的 活跃request 为0
    
    NSString *name = [NSString stringWithFormat:@"downloadFile.syschronzied-%@",[[NSUUID UUID] UUIDString]];
    
    //初始化同步队列
    self.synchromizationQueue = dispatch_queue_create([name cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);//串行 同步队列
    
    return self;
}

//下载
- (CDownLoadReceipItem *)downloadFileWithUrl:(NSString *)url
                                    progress:(void (^)(NSProgress * _Nonnull, CDownLoadReceipItem * _Nonnull))progressBlcok
                                    destinationPath:(NSURL *  (^)(NSURL * _Nonnull, NSURLResponse * _Nonnull))destinationBlock
                                     success:(void (^)(NSURLRequest *request,NSURLResponse *response,NSURL *filePath))success
                                      failed:(void (^)(NSURLRequest *request,NSURLResponse *response,NSError *error))failed
{
   __block CDownLoadReceipItem *downloadItem = [self prepareDownloadReceiptForUrl:url];//根据url 查找或创建一个receiptItem

    //开启一个队列去下载
    dispatch_sync(self.synchromizationQueue, ^{
        NSString *urlStr = url;
        
        if (urlStr == nil) {
            if (failed) {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    failed(nil,nil,error);
                });
            }
        }
        downloadItem.successBlock = success;
        downloadItem.failBlock = failed;//保持参数顺序一样
        downloadItem.progressBlock = progressBlcok;
        
         //完成下载
        if (downloadItem.status == CDownLoadReceipItemStatusCompleted && downloadItem.receiptBytes == downloadItem.totalBytes) {
           
            dispatch_async(dispatch_get_main_queue(), ^{
                if (downloadItem.successBlock) {
                    downloadItem.successBlock(nil,nil,[NSURL URLWithString:downloadItem.url]);
                }
            });
            return ;
            
        }
        //下载中
        if (downloadItem.status == CDownLoadReceipItemStatusDownloading && downloadItem.receiptBytes != downloadItem.totalBytes){
        
            dispatch_async(dispatch_get_main_queue(), ^{
                if (downloadItem.progressBlock) {
                    downloadItem.progressBlock(downloadItem.progress,downloadItem);
                }
            });
            
            return;
        }
 
        NSURLSessionDataTask *task = self.tasks[downloadItem.url];
        // 当请求暂停一段时间后。task的状态会变化为 NSURLSessionTaskStateCompleted ，会出现请求超时downloadFailed 这个状态这时候需要根据已有的totalBytes 设置range 重新开启一个请求 设置新的task 。所有要判断下状态
        NSLog(@"task 的state 变化 %ld",task.state);
        if (!task || ((task.state != NSURLSessionTaskStateRunning) && (task.state != NSURLSessionTaskStateSuspended))) { //首次下载 是从这里开始
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:downloadItem.url]];
            
            //实现断点下载 需要添加http 头的range， eg:bytes=500- 表示从500字节的位置开始下载
            //bytes=-500 表示最后500字节  或者是100-500 - 用于分隔前面的数字表示起始的字节数后面的数字表示截止的字节数，没有表示道末尾， 用于分组，可以一次指定多个Range，不过很少用
            NSString *range = [NSString stringWithFormat:@"bytes=%zd-", downloadItem.receiptBytes];
            [request setValue:range forHTTPHeaderField:@"Range"];
            
            
            NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
            task.taskDescription = downloadItem.url;//后面再dataDelegate 的方法通过task 直接获取 url 可以在字典中获取对应的receiptItem
    
            self.tasks[downloadItem.url] = task;
            
            NSLog(@"url is %@,task is %@",downloadItem.url,task);
            [self.queuedTasks addObject:task];
           
            
        }
            [self resumeTaskWithRecepit:downloadItem];
    
        
        
        

    });
    
    return downloadItem;
}

//准备一个receiptItem 如果存在则取出，如果不存在 则创建
- (CDownLoadReceipItem *)prepareDownloadReceiptForUrl:(NSString *)url
{
    if (url == nil) {
        NSLog(@"url is NULL");
        return nil;
    }
    
    //从所有的url字典中根据url键值查找对于的item
    CDownLoadReceipItem *item = self.allDownloadReceipts[url];
    
    NSLog(@"所有receiptItem 个数 -->%ld",self.allDownloadReceipts.count);
    //如果字典中存在 则返回，否则创建新的receiptItem
    if (item ) {
        NSLog(@"item数组中 含有已经存在的 receipteItem");
        return item;
    }else{
        NSLog(@"--item数组中 不含有已经存在的 receipteItem--");

        item = [[CDownLoadReceipItem alloc] initWithUrl:url];
        item.status = CDownLoadReceipItemNone;//初始化item 状态为NONE
        item.totalBytes = 1;
        item.receiptBytes = 0;
        dispatch_sync(self.synchromizationQueue, ^{
            [self.allDownloadReceipts setObject:item forKey:url];//保存到字典
//            //归档存储一下
//            [self saveArvhiceAllReceiptDict:self.allDownloadReceipts];
        });
    }
    return item;
    
}
#pragma mark -- suspend task
//suspend download 暂停一个下载
-(void)suspendWithURL:(NSString *)url {
    
    if (url == nil) return;
    
    CDownLoadReceipItem *receipt = [self prepareDownloadReceiptForUrl:url];
    [self suspendDownloadWith:receipt];
}

- (void)suspendDownloadWith:(CDownLoadReceipItem *)recepiteItem
{
   
    //取出要暂停的下载task
    NSURLSessionTask *task = self.tasks[recepiteItem.url];
    if (task) {
        [task suspend];
    }
    //更换状态
     [self updateReceiptStatusWith:recepiteItem.url withStatus:CDownLoadReceipItemStatusSuspened];
}

#pragma mark -- continue task loading
//继续一个下载任务
- (void)resumeTaskWithRecepit:(CDownLoadReceipItem *)receiptItem
{
    NSLog(@"状态是什么  %ld",receiptItem.status);
//    if(receiptItem.status == CDownLoadReceipItemStatusSuspened || receiptItem.status == CDownLoadReceipItemFailed){
        //获取这个receipt对应的task
        NSURLSessionTask *task = self.tasks[receiptItem.url];
        if (!task || ((task.state != NSURLSessionTaskStateRunning)&&(task.state != NSURLSessionTaskStateSuspended))) {
            [self downloadFileWithUrl:task.taskDescription progress:receiptItem.progressBlock destinationPath:nil success:receiptItem.successBlock failed:receiptItem.failBlock];
        }else{
           //开始任务
            [self startTaskWtihTask:self.tasks[receiptItem.url]];
        }
//    }
}
- (void)startTaskWtihTask:(NSURLSessionDataTask *)task
{
    
    [task resume];//开始这个任务
    //更新一些这个receipt 的状态
    [self updateReceiptStatusWith:task.taskDescription withStatus:CDownLoadReceipItemStatusDownloading];
    
}
- (CDownLoadReceipItem *)updateReceiptStatusWith:(NSString *)url withStatus:(CDownLoadReceipItemStatus)status
{
    CDownLoadReceipItem *receipteIte = [self prepareDownloadReceiptForUrl:url];
    receipteIte.status = status;
    
    return receipteIte;
}
#pragma mark --NSUrlSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(nonnull NSURLResponse *)response completionHandler:(nonnull void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSString *itemUrl = dataTask.taskDescription;
    CDownLoadReceipItem *receiptItem = self.allDownloadReceipts[itemUrl];
    receiptItem.totalBytes = receiptItem.totalBytes + dataTask.countOfBytesExpectedToReceive;
    receiptItem.status = CDownLoadReceipItemStatusDownloading;
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    __block CDownLoadReceipItem *receiptItem = self.allDownloadReceipts[dataTask.taskDescription];
    __block NSError *error = nil;
    dispatch_sync(self.synchromizationQueue, ^{
        NSInputStream *inputSteam = [[NSInputStream alloc] initWithData:data];
        NSOutputStream *outputSteam = [[NSOutputStream alloc] initWithURL:[NSURL fileURLWithPath:receiptItem.filePath] append:YES];//拼接data
        [inputSteam open];
        [outputSteam open];
        
        while ([inputSteam hasBytesAvailable] && [outputSteam hasSpaceAvailable]) {//还有待输入bytes 和输出空间
            
            uint8_t buffer[1024];
            //从流中读取数据 到buffer len 指定最大的长度为多少
            NSInteger bytesRead = [inputSteam read:buffer maxLength:1024];
            if(inputSteam.streamError || bytesRead < 0){
                error = inputSteam.streamError;
                break;
            }
            
            //从输出流中写 到buffer
            NSInteger bytesWritten = [outputSteam write:buffer maxLength:(NSInteger)bytesRead];//最大不超多 读出的长度
            if(outputSteam.streamError || bytesWritten<0){
                error = outputSteam.streamError;
                break;
            }
            
            //可读可写 都无
            if (bytesRead == 0 && bytesWritten == 0) {
                break;
            }
        }
        
        [outputSteam close];
        [inputSteam close];
        
        receiptItem.progress.totalUnitCount = receiptItem.totalBytes;
        receiptItem.progress.completedUnitCount = receiptItem.receiptBytes;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (receiptItem.progressBlock) {
                receiptItem.progressBlock(receiptItem.progress,receiptItem);
            }
        });
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    CDownLoadReceipItem *item = [self prepareDownloadReceiptForUrl:task.taskDescription];
    if (error) {
        item.status = CDownLoadReceipItemFailed;//状态改变为失败
        dispatch_async(dispatch_get_main_queue(), ^{
            if (item.failBlock) {
                item.failBlock(task.originalRequest,task.response,error);
            }
        });
    }else{
        [item.stream close];
        item.stream = nil;
        item.status = CDownLoadReceipItemStatusCompleted;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (item.successBlock) {
                item.successBlock(task.originalRequest,task.response,task.originalRequest.URL);
            }
        });
    }
    
    //打印一下 接收的文件的路径
    NSLog(@"save path is %@",item.filePath);
}
- (void)saveArvhiceAllReceiptDict:(NSMutableDictionary *)allReceipteDict
{
//    [NSKeyedArchiver ]
}
@end
