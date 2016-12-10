//
//  CDownLoadReceipItem.h
//  CDownLoadManager
//
//  Created by Lemon HOLL on 2016/12/8.
//  Copyright © 2016年 Lemon HOLL. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class CDownLoadReceipItem;

//下载item 状态
typedef enum : NSUInteger {
    CDownLoadReceipItemNone,//开始状态 none
    CDownLoadReceipItemStatusDownloading,//下载状态
    CDownLoadReceipItemStatusCompleted,//下载完成
    CDownLoadReceipItemStatusSuspened,//暂停下载
    CDownLoadReceipItemFailed,//下载失败
} CDownLoadReceipItemStatus;

typedef void(^CDownLoadSucessBlock)(NSURLRequest * _Nullable, NSURLResponse * _Nullable, NSURL * _Nonnull);

typedef void(^CDownLoadFailedBlock)(NSURLRequest * _Nullable, NSURLResponse * _Nullable,  NSError * _Nonnull);

typedef void (^CDProgressBlock)(NSProgress * _Nonnull, CDownLoadReceipItem *downloadItem);



@interface CDownLoadReceipItem : NSObject


@property (nonatomic, copy)CDownLoadSucessBlock successBlock;
@property (nonatomic, copy) CDownLoadFailedBlock failBlock;
@property (nonatomic, copy)CDProgressBlock progressBlock;

@property (strong, nonatomic) NSOutputStream *stream;
/*
 item download url
 */
@property (nonatomic, strong) NSString *url;
/*
 item download status
 */
@property (nonatomic, assign) CDownLoadReceipItemStatus status;
/*
 item 存储path
 */
@property (nonatomic, strong) NSString *filePath;
/*
 item fileName
 */
@property (nonatomic, strong) NSString *fileName;
/*
item 已接收 bytes
 */
@property (nonatomic, assign) long long receiptBytes;
/*
 item 总共 bytes
 */
@property (nonatomic, assign) long long totalBytes;
/*
 item download progress
 */
@property (nonatomic, strong) NSProgress *progress;
/*
 download error
 */
@property (nonatomic, strong) NSError *error;


- (instancetype)initWithUrl:(NSString *)url;
NS_ASSUME_NONNULL_END
@end
