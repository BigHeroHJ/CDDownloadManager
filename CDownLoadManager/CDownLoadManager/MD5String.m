//
//  MD5String.m
//  CDownLoadManager
//
//  Created by Lemon HOLL on 2016/12/8.
//  Copyright © 2016年 Lemon HOLL. All rights reserved.
//

#import "MD5String.h"
#import <CommonCrypto/CommonDigest.h>

@implementation MD5String
+ (NSString *)converttoMD5WithString:(NSString *)string
{
    if (string == nil) {
        return nil;
    }else{
        const char *cstring = string.UTF8String;
        unsigned char bytes[CC_MD5_DIGEST_LENGTH];
        CC_MD5(cstring, (CC_LONG)strlen(cstring), bytes);
        NSMutableString *md5String = [NSMutableString string];
        for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
            [md5String appendFormat:@"%02x", bytes[i]];
        }
        return md5String;
    }
}
@end
