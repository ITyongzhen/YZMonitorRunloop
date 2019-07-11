//
//  YZLogFile.m
//  YZMonitorRunLoopDemo
//
//  Created by eagle on 2019/6/18.
//  Copyright © 2019 yongzhen. All rights reserved.
//

#import "YZLogFile.h"
#import "SSZipArchive.h"
#import "YZAppInfoUtil.h"

static const float DefaultMAXLogFileLength = 50;
@implementation YZLogFile
#pragma mark -  日志模块
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static YZLogFile *cls;
    dispatch_once(&onceToken, ^{
        cls = [[[self class] alloc] init];
    });
    return cls;
}

-(NSString *)getLogPath{
    NSArray *paths  = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
    NSString *homePath = [paths objectAtIndex:0];
    
    NSString *filePath = [homePath stringByAppendingPathComponent:@"Caton.log"];
    return filePath;
}

-(NSString *)getLogZipPath{
    NSFileManager *myFileManager = [NSFileManager defaultManager];
    NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *zipPath = [NSString stringWithFormat:@"%@/Caton.zip",cachesDirectory];
    [myFileManager removeItemAtPath:zipPath error:nil];
    return zipPath;
}

- (void)writefile:(NSString *)string
{
    NSString *filePath = [self getLogPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if(![fileManager fileExistsAtPath:filePath]) //如果不存在
    {
        NSString *str = @"卡顿日志";
        NSString *systemVersion = [NSString stringWithFormat:@"手机版本: %@",[YZAppInfoUtil iphoneSystemVersion]];
        NSString *iphoneType = [NSString stringWithFormat:@"手机型号: %@",[YZAppInfoUtil iphoneType]];
        str = [NSString stringWithFormat:@"%@\n%@\n%@",str,systemVersion,iphoneType];
        [str writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
    }else{
        float filesize = -1.0;
        if ([fileManager fileExistsAtPath:filePath]) {
            NSDictionary *fileDic = [fileManager attributesOfItemAtPath:filePath error:nil];
            unsigned long long size = [[fileDic objectForKey:NSFileSize] longLongValue];
            filesize = 1.0 * size / 1024;
        }
        
        NSLog(@"文件大小 filesize = %lf",filesize);
        NSLog(@"文件内容 %@",string);
        NSLog(@" ---------------------------------");
        
        if (filesize > (self.MAXFileLength > 0 ? self.MAXFileLength:DefaultMAXLogFileLength)) {
            // 上传到服务器
            NSLog(@" 上传到服务器");
            [self update];
            [self clearLocalLogFile];
            [self writeToLocalLogFilePath:filePath contentStr:string];
        }else{
            NSLog(@"继续写入本地");
            [self writeToLocalLogFilePath:filePath contentStr:string];
        }
    }
    
}

-(void)writeToLocalLogFilePath:(NSString *)localFilePath contentStr:(NSString *)contentStr{
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:localFilePath];
    
    [fileHandle seekToEndOfFile];  //将节点跳到文件的末尾
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *datestr = [dateFormatter stringFromDate:[NSDate date]];
    
    NSString *str = [NSString stringWithFormat:@"\n%@\n%@",datestr,contentStr];
    
    NSData* stringData  = [str dataUsingEncoding:NSUTF8StringEncoding];
    
    [fileHandle writeData:stringData]; //追加写入数据
    
    [fileHandle closeFile];
}

-(BOOL)clearLocalLogFile{
    NSFileManager *myFileManager = [NSFileManager defaultManager];
    return [myFileManager removeItemAtPath:[self getLogPath] error:nil];
    
}

-(BOOL)clearLocalLogZipFile{
    NSFileManager *myFileManager = [NSFileManager defaultManager];
    return [myFileManager removeItemAtPath:[self getLogZipPath] error:nil];
    
}

-(BOOL)clearLocalLogZipAndLogFile{
    return [self clearLocalLogFile] && [self clearLocalLogZipFile];
    
}
// 上传日志
-(void)update{
    NSString *zipPath = [self getLogZipPath];
    NSString *password = nil;
    NSMutableArray *filePaths = [[NSMutableArray alloc] init];
    [filePaths addObject:[self getLogPath]];
    BOOL success = [SSZipArchive createZipFileAtPath:zipPath withFilesAtPaths:filePaths withPassword:password.length > 0 ? password : nil];
    
    if (success) {
        NSLog(@"压缩成功");
        
    }else{
        NSLog(@"压缩失败");
    }
    
    
}

@end
