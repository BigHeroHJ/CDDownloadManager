//
//  CDownLoadManager.h
//  CDownLoadManager
//
//  Created by Lemon HOLL on 2016/12/8.
//  Copyright © 2016年 Lemon HOLL. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CDownLoadReceipItem;

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    CDownLoadManagerPrioritizeFIFO,  /** first in first out */
    CDownLoadManagerPrioritizeLIFO   /** last in first out */
    
} CDownLoadManagerPrioritize;

@interface CDownLoadManager : NSObject

@property (nonatomic, assign) CDownLoadManagerPrioritize downloadPrioritize;


/*
 单例类
 */
+ (instancetype)shareInstance;


//初始化
- (id) init;

- (instancetype)initWithSession:(NSURLSession *)session downloadPrioritization:(CDownLoadManagerPrioritize)downloadPrioritization maximumActiveDownloads:(NSInteger)maximumActiveDownloads;


//类似af 中的downloadTask 方法
- (CDownLoadReceipItem *)downloadFileWithUrl:(NSString * _Nullable )url
                                    progress:(void (^)(NSProgress * downloadProgress, CDownLoadReceipItem *receiptItem)) progressBlcok
                                    destinationPath:(NSURL * (^)(NSURL *targetPath,NSURLResponse *response))destinationBlock
                                    success:(void (^)(NSURLRequest *request,NSURLResponse *response,NSURL *filePath))success
                                      failed:(void (^)(NSURLRequest *request,NSURLResponse *response,NSError *error))failed;


- (CDownLoadReceipItem *_Nullable)prepareDownloadReceiptForUrl:(NSString *)url;

/*
 暂停一个正在下载的任务
 */
- (void)suspendDownloadWith:(CDownLoadReceipItem *)recepiteItem;
NS_ASSUME_NONNULL_END
@end
