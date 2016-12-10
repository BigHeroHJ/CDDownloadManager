//
//  DownloadController.m
//  CDownLoadManager
//
//  Created by Lemon HOLL on 2016/12/8.
//  Copyright © 2016年 Lemon HOLL. All rights reserved.
//

#import "DownloadController.h"
#import "CDownLoadManager.h"
#import "CDownLoadReceipItem.h"
#import "DownloadCell.h"

#define SCREENWIDTH [UIScreen mainScreen].bounds.size.width
#define SCREENHEIGHT [UIScreen mainScreen].bounds.size.height


@interface DownloadController ()<UITableViewDelegate,UITableViewDataSource>
{
    UITableView   * _tableview;
    CDownLoadManager  * _downloadManager;
    NSMutableArray *_urls;
}
@end

@implementation DownloadController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    

    _urls = [NSMutableArray array];
    [self getData];
    
    _tableview = [[UITableView alloc] initWithFrame:CGRectMake(0, 20, SCREENWIDTH, SCREENHEIGHT - 20) style:UITableViewStylePlain];
    _tableview.delegate = self;
    _tableview.dataSource = self;
    _tableview.separatorStyle = UITableViewCellSelectionStyleNone;
    [self.view addSubview:_tableview];
    
    _downloadManager = [CDownLoadManager shareInstance];
    
}

- (void)getData
{
//    NSString * urlStr = @"http://120.25.226.186:32812/resources/videos/minion_%02d.mp4";
    for (int i = 1; i<= 10; i++) {
        NSString *downloadUrl = [NSString stringWithFormat:@"http://120.25.226.186:32812/resources/videos/minion_%02d.mp4",i];
        [_urls addObject:downloadUrl];
    }
}
#pragma mark --delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _urls.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *cellId = @"DownloadCell";
    DownloadCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[NSBundle mainBundle] loadNibNamed:@"DownloadCell" owner:nil options:nil].firstObject;
       
    }
     cell.url = _urls[indexPath.row];
    
    return cell;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 100;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
