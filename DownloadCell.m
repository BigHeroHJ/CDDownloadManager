//
//  DownloadCell.m
//  CDownLoadManager
//
//  Created by Lemon HOLL on 2016/12/8.
//  Copyright © 2016年 Lemon HOLL. All rights reserved.
//

#import "DownloadCell.h"
#import "CDownLoadManager.h"
#import "CDownLoadReceipItem.h"

@implementation DownloadCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}


//点击事件
- (IBAction)btnClick:(UIButton *)sender {
    CDownLoadReceipItem *recepitItem = [[CDownLoadManager shareInstance] prepareDownloadReceiptForUrl:_url];
    NSLog(@"receipt status %ld",recepitItem.status);
    if (recepitItem.status == CDownLoadReceipItemStatusDownloading ) {
        [self.beginLoad setTitle:@"下载" forState:UIControlStateNormal];
        [[CDownLoadManager shareInstance] suspendDownloadWith:recepitItem];
    }else if(recepitItem.status == CDownLoadReceipItemStatusCompleted){
        [self.beginLoad setTitle:@"完成" forState:UIControlStateNormal];
    }else {//如果点击 意图是需要下载的情况，则对应的状态应该有 suspend failed none 三种
        [self.beginLoad setTitle:@"停止" forState:UIControlStateNormal];
         [self download];
    }
   
}


//开始下载
- (void)download
{
    NSLog(@"loding..");
    
    [[CDownLoadManager shareInstance] downloadFileWithUrl:self.url progress:^(NSProgress * _Nonnull downloadProgress, CDownLoadReceipItem * _Nonnull receiptItem) {
        self.progress.progress = downloadProgress.fractionCompleted;
        NSLog(@"progress %f",downloadProgress.fractionCompleted);
    } destinationPath:nil
     success:^(NSURLRequest * _Nonnull request, NSURLResponse * _Nonnull response, NSURL * _Nonnull filePath) {
        NSLog(@"success file path %@",filePath);
    } failed:^(NSURLRequest * _Nonnull request, NSURLResponse * _Nonnull response, NSError * _Nonnull error) {
        if(error){
             [self.beginLoad setTitle:error.localizedDescription forState:UIControlStateNormal];
        }
//        [self.beginLoad setTitle:@"下载" forState:UIControlStateNormal];
        NSLog(@"error is %@",error.localizedDescription);
    }];
    
}
- (void)setUrl:(NSString *)url
{
    _url = url;
    self.titleLabel.text = url.lastPathComponent;
    CDownLoadReceipItem *recepitItem = [[CDownLoadManager shareInstance] prepareDownloadReceiptForUrl:url];
    NSLog(@"recepiteItem.progress.fractionCompleted %lf",recepitItem.progress.fractionCompleted);
    self.progress.progress = recepitItem.progress.fractionCompleted;
    self.receiptItem = recepitItem;
    
    if (recepitItem.status == CDownLoadReceipItemStatusDownloading) {
        [self.beginLoad setTitle:@"下载中" forState:UIControlStateNormal];
    }else if (recepitItem.status == CDownLoadReceipItemStatusCompleted) {
        [self.beginLoad setTitle:@"完成下载" forState:UIControlStateNormal];
    }else {
        [self.beginLoad setTitle:@"下载" forState:UIControlStateNormal];
    }
    
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
