//
//  YZCallStack.h
//  rongxin4
//
//  Created by eagle on 2019/6/18.
//  Copyright © 2019 yongzhen. All rights reserved.
//

// 该类获取函数调用堆栈
#import <Foundation/Foundation.h>

#define YZLOG_Callstack_Current NSLog(@"%@",[BSBacktraceLogger YZ_backtraceOfCurrentThread]);
#define YZLOG_Callstack_MAIN NSLog(@"%@",[BSBacktraceLogger YZ_backtraceOfMainThread]);
#define YZLOG_Callstack_ALL NSLog(@"%@",[BSBacktraceLogger YZ_backtraceOfAllThread]);
/**
 获取函数调用栈
 Xcode 的调试输出不稳定，有时候存在调用 NSLog() 但没有输出结果的情况，建议前往 控制台 中根据设备的 UUID 查看完整输出。
 真机调试和使用 Release 模式时，为了优化，某些符号表并不在内存中，而是存储在磁盘上的 dSYM 文件中，无法在运行时解析，因此符号名称显示为 <redacted>。
 关于dSYM可以参考https://github.com/answer-huang/dSYMTools
 参考 https://github.com/bestswifter/BSBacktraceLogger
 */
@interface YZCallStack : NSObject
+ (NSString *)yz_backtraceOfAllThread;
+ (NSString *)yz_backtraceOfCurrentThread;
+ (NSString *)yz_backtraceOfMainThread;
+ (NSString *)yz_backtraceOfNSThread:(NSThread *)thread;
@end

