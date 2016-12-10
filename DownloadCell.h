//
//  DownloadCell.h
//  CDownLoadManager
//
//  Created by Lemon HOLL on 2016/12/8.
//  Copyright © 2016年 Lemon HOLL. All rights reserved.
//

#import <UIKit/UIKit.h>
@class CDownLoadReceipItem;
@interface DownloadCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UIProgressView *progress;
@property (strong, nonatomic) IBOutlet UIButton *beginLoad;
@property (nonatomic,copy)NSString *url;

@property (nonatomic, strong) CDownLoadReceipItem *receiptItem;
@end
