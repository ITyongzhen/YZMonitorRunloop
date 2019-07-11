//
//  YZLogFile.h
//  YZMonitorRunLoopDemo
//
//  Created by eagleon 2019/6/18.
//  Copyright © 2019 yongzhen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YZLogFile : NSObject
@property (nonatomic,assign) float MAXFileLength;// 最大本地日志，高于这个数字，就上传，单位 kb

- (void)writefile:(NSString *)string;
+ (instancetype)sharedInstance;
@end

NS_ASSUME_NONNULL_END
