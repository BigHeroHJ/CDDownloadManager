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


static NSString *const CDownloadCachesFolderName = @"CDownloadCache";

//在library 路径下新建一个CDownloadCache 的文件夹 每个文件存储在这个文件夹内部
static  NSString * cachesFolder() {
    NSFileManager *filem = [NSFileManager defaultManager];
    static NSString *cachesFolder ;
    static dispatch_once_t oncetoken;
    dispatch_once(&oncetoken, ^{
        if (cachesFolder == nil) {
            NSString *cachesDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            cachesFolder = [cachesDir stringByAppendingPathComponent:CDownloadCachesFolderName];
        }
        
        NSError *error = nil;
        
        if (![filem createDirectoryAtPath:cachesFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"failed to creat new directory at %@", cachesFolder);
            cachesFolder = nil;
        }
    });
    return cachesFolder;
}


static NSString *allReceiptDictSavePath() {
    return [cachesFolder() stringByAppendingPathComponent:@"receipt.data"];
}

@interface CDownLoadManager()<NSURLSessionDataDelegate,NSURLSessionDelegate>



@property (nonatomic, strong) NSURLSession *session; // 管理下载的session
@property (nonatomic, strong) dispatch_queue_t synchromizationQueue;//这个Manager 进行所有任务下载操作的队列

@property (nonatomic, assign) NSInteger maxNumActiveDownloads;//最大活跃的下载数。 未实现
@property (nonatomic, assign) NSUInteger activeReqestCount;//当前在请求的request数量

@property (nonatomic, strong) NSMutableArray *queuedTasks;
@property (nonatomic, strong) NSMutableDictionary *tasks;//任务task 和 对应的url 的键值对

@property (nonatomic, strong) NSMutableDictionary *allDownloadReceipts;//所有的正在下载的item 也是对应的url 键值对

@end


@implementation CDownLoadManager

- (NSMutableDictionary *)allDownloadReceipts
{
    if (_allDownloadReceipts == nil) {
        
    NSMutableDictionary *dict = [self unArchiveAllReceiptDict];
        
//        for(int i = 0;i < dict.allKeys.count;i++){
//            CDownLoadReceipItem *item = [dict objectForKey:dict.allKeys[i]];;
//            NSLog(@" self.allreceipt归档中取出的接收的数据量 %lld -- %lld --%@--%@--%ld",item.receiptBytes,item.totalBytes,item.url,item.fileName,item.status);
//        }
    if (dict.allKeys.count != 0 ) {
        for(int i = 0;i < dict.allKeys.count;i++){
            CDownLoadReceipItem *item = [dict objectForKey:dict.allKeys[i]];;
            NSLog(@" 归档中取出的接收的数据量 %lld--%@--%@--%ld",item.receiptBytes,item.url,item.fileName,item.status);
        }
        _allDownloadReceipts = [dict mutableCopy];
    }else{
        _allDownloadReceipts = [NSMutableDictionary dictionary];
        [self saveArvhiceAllReceiptDict:_allDownloadReceipts];
    }
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
    configuration.timeoutIntervalForRequest = 10.0;//请求超时的时间
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
    __unsafe_unretained CDownLoadManager *weakSelf = self;
    dispatch_sync(weakSelf.synchromizationQueue, ^{
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
 
        NSURLSessionDataTask *task = weakSelf.tasks[downloadItem.url];
        // 当请求暂停一段时间后。task的状态会变化为 NSURLSessionTaskStateCompleted ，会出现请求超时downloadFailed 这个状态这时候需要根据已有的totalBytes 设置range 重新开启一个请求 设置新的task 。所有要判断下状态
//        NSLog(@"task 的state 变化 %ld",task.state);
        if (!task || ((task.state != NSURLSessionTaskStateRunning) && (task.state != NSURLSessionTaskStateSuspended))) { //首次下载 是从这里开始
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:downloadItem.url]];
            
            //实现断点下载 需要添加http 头的range， eg:bytes=500- 表示从500字节的位置开始下载
            //bytes=-500 表示最后500字节  或者是100-500 - 用于分隔前面的数字表示起始的字节数后面的数字表示截止的字节数，没有表示道末尾， 用于分组，可以一次指定多个Range，不过很少用
            NSString *range = [NSString stringWithFormat:@"bytes=%zd-", downloadItem.receiptBytes];
            [request setValue:range forHTTPHeaderField:@"Range"];
            
            
            NSURLSessionDataTask *task = [weakSelf.session dataTaskWithRequest:request];
            task.taskDescription = downloadItem.url;//后面再dataDelegate 的方法通过task 直接获取 url 可以在字典中获取对应的receiptItem
    
//            NSLog(@"downloadItem.url is --->,%@",downloadItem.url);
//            self.tasks[downloadItem.url] = task;
            [weakSelf.tasks setObject:task forKey:downloadItem.url];
            
//            NSLog(@"url is %@,task is %@",downloadItem.url,task);
            [weakSelf.queuedTasks addObject:task];
        
        }
            [weakSelf resumeTaskWithRecepit:downloadItem];
    });
    
    return downloadItem;
}

//准备一个receiptItem 如果存在则取出，如果不存在 则创建
- (CDownLoadReceipItem *)prepareDownloadReceiptForUrl:(NSString *)url
{
    if (url == nil) {
//        NSLog(@"url is NULL");
        return nil;
    }
    
    //从所有的url字典中根据url键值查找对于的item
    CDownLoadReceipItem *item = self.allDownloadReceipts[url];
    
//    NSLog(@"所有receiptItem 个数 -->%ld",self.allDownloadReceipts.count);
    //如果字典中存在 则返回，否则创建新的receiptItem
    if (item ) {
//        NSLog(@"item.receiptBytes is %lld",item.receiptBytes);
        return item;
    }else{
        item = [[CDownLoadReceipItem alloc] initWithUrl:url];
        item.status = CDownLoadReceipItemNone;//初始化item 状态为NONE
        item.totalBytes = 0;
        item.receiptBytes = 0;
        item.url = url;
        dispatch_sync(self.synchromizationQueue, ^{
            [self.allDownloadReceipts setObject:item forKey:url];//保存到字典
            //归档存储一下
            [self saveArvhiceAllReceiptDict:self.allDownloadReceipts];
        });
//         NSLog(@"item.progress is %lld",item.progress.completedUnitCount);
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
//    NSLog(@"状态是什么  %ld",receiptItem.status);
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
    
    //保存一下状态到归档
    [self saveArvhiceAllReceiptDict:self.allDownloadReceipts];
    [self unArchiveAllReceiptDict];
    
    return receipteIte;
}
#pragma mark --NSUrlSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(nonnull NSURLResponse *)response completionHandler:(nonnull void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSString *itemUrl = dataTask.taskDescription;
    CDownLoadReceipItem *receiptItem = self.allDownloadReceipts[itemUrl];
    receiptItem.totalBytes = receiptItem.receiptBytes + dataTask.countOfBytesExpectedToReceive;//这个是每次请求task 的总数据是已写的数据加上这次 预计接收的数据量，有暂停时间过久重新请求task 。
    receiptItem.status = CDownLoadReceipItemStatusDownloading;
    
    completionHandler(NSURLSessionResponseAllow);
    
     [self saveArvhiceAllReceiptDict:self.allDownloadReceipts];
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
        
        NSLog(@"总共的data-->%lld , 接收的data--%lldd",receiptItem.totalBytes,receiptItem.receiptBytes);
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
    
    [self saveArvhiceAllReceiptDict:self.allDownloadReceipts];
    //打印一下 接收的文件的路径
    NSLog(@"save path is %@",item.filePath);
}

#pragma mark -- 给对象进行归档  & 解归档

- (void)saveArvhiceAllReceiptDict:(NSMutableDictionary *)allReceipteDict
{
    for (int i = 0; i< allReceipteDict.allKeys.count; i++) {
        NSString *key = allReceipteDict.allKeys[i];
        CDownLoadReceipItem *item = [allReceipteDict objectForKey:key];
        NSLog(@"归档的时候 打印 每个item接收的数据量 -- %lld %lld  key---%@ --存储地址%@",item.totalBytes,item.receiptBytes,key,item.filePath);
    }
    [NSKeyedArchiver archiveRootObject:allReceipteDict toFile:allReceiptDictSavePath()];
    
//    [self.allDownloadReceipts writeToFile:allReceiptDictSavePath() atomically:YES];
//    [[NSUserDefaults standardUserDefaults] setObject:self.allDownloadReceipts forKey:@"dict"];
}

- (NSMutableDictionary *)unArchiveAllReceiptDict
{
    NSMutableDictionary *dict = [[NSKeyedUnarchiver unarchiveObjectWithFile:allReceiptDictSavePath()] mutableCopy];
//    NSMutableDictionary *dict = [[NSMutableDictionary dictionaryWithContentsOfFile:allReceiptDictSavePath()] mutableCopy];
//    NSMutableDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:@"dict"];
    for (int i = 0; i< dict.allKeys.count; i++) {
        NSString *key = dict.allKeys[i];
        CDownLoadReceipItem *item = [dict objectForKey:key];
       NSLog(@" 归档中取出的接收的数据量 %lld --%lld--%@--%@--%ld--存储地址%@",item.receiptBytes,item.totalBytes,item.url,item.fileName,item.status,item.filePath);
    }
    return dict;
}

@end
