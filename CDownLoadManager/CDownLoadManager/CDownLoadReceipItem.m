//
//  CDownLoadReceipItem.m
//  CDownLoadManager
//
//  Created by Lemon HOLL on 2016/12/8.
//  Copyright © 2016年 Lemon HOLL. All rights reserved.
//

#import "CDownLoadReceipItem.h"
#import "MD5String.h"

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

//返回该路径下文件的大小
static unsigned long long fileSizeForPath(NSString *path) {
    
    signed long long fileSize = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        NSDictionary *fileDict = [fileManager attributesOfItemAtPath:path error:&error];
        if (!error && fileDict) {
            fileSize = [fileDict fileSize];
        }
    }
    return fileSize;
}


@implementation CDownLoadReceipItem



- (instancetype)initWithUrl:(NSString *)url
{
    if (self = [self init]) {
        _url = url;
    }
    return self;
}


#pragma mark --lazyload filePath
- (NSString *)filePath
{
    NSString *path = [cachesFolder() stringByAppendingPathComponent:self.fileName];
    if (_filePath == nil) {
        _filePath = path;
    }
    return _filePath;
}

- (long long)receiptBytes
{
    return fileSizeForPath(self.filePath);
}

#pragma mark --lazylaod fileName
- (NSString *)fileName
{
    if (_fileName == nil) {
        NSString *pathExtension = self.url.pathExtension;
        if (pathExtension.length) {
            _fileName = [NSString stringWithFormat:@"%@.%@", [MD5String converttoMD5WithString:self.url], pathExtension];
        } else {
            _fileName = [MD5String converttoMD5WithString:self.url];
        }
    }
    
    return _fileName;
}
#pragma mark --lazyload stream
- (NSOutputStream *)stream
{
    if ( _stream == nil) {
        _stream = [NSOutputStream outputStreamToFileAtPath:self.filePath append:YES];
    }
    return _stream;
}
#pragma mark --lazyload progress
- (NSProgress *)progress
{
    if (_progress == nil) {
        _progress = [[NSProgress alloc] init];
    }
    
    //设置progress 的 已完成 和 全部数据的属性
    _progress.completedUnitCount = self.receiptBytes;
    _progress.totalUnitCount = self.totalBytes;
    
    return _progress;
}
#pragma mark - NSCoding
- (void)encodeWithCoder:(NSCoder *)aCoder
{
//    [aCoder encodeObject:self.url forKey:NSStringFromSelector(@selector(url))];
//    [aCoder encodeObject:self.filePath forKey:NSStringFromSelector(@selector(filePath))];
//    [aCoder encodeObject:@(self.status) forKey:NSStringFromSelector(@selector(status))];
//    [aCoder encodeObject:self.fileName forKey:NSStringFromSelector(@selector(fileName))];
//    [aCoder encodeObject:@(self.receiptBytes) forKey:NSStringFromSelector(@selector(receiptBytes))];
//    [aCoder encodeObject:@(self.totalBytes) forKey:NSStringFromSelector(@selector(totalBytes))];
    [aCoder encodeObject:self.url forKey:@"itemUrl"];
    [aCoder encodeObject:self.filePath forKey:@"filePath"];
    [aCoder encodeInteger:self.status forKey:@"status"];
    [aCoder encodeObject:self.fileName forKey:@"fileName"];
    [aCoder encodeInteger:self.receiptBytes forKey:@"receiptBytes"];
    [aCoder encodeInteger:self.totalBytes forKey:@"totalBytes"];
  
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
//        self.url = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(url))];
//        self.filePath = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(filePath))];
//        self.status = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(state))] unsignedIntegerValue];
//        self.fileName = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(filename))];
//        self.receiptBytes = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(receiptBytes))] unsignedIntegerValue];
//        self.totalBytes = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(totalBytes))] unsignedIntegerValue];
        
        self.url = [aDecoder decodeObjectForKey:@"itemUrl"];
        self.filePath = [aDecoder decodeObjectForKey:@"filePath"];
        self.status = [aDecoder decodeIntegerForKey:@"status"];
        self.fileName = [aDecoder decodeObjectForKey:@"fileName"];
        self.receiptBytes = [aDecoder decodeIntegerForKey:@"receiptBytes"];
        self.totalBytes = [aDecoder decodeIntegerForKey:@"totalBytes"];
        
    }
    return self;
}

@end
