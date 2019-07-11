//
//  YZMonitorRunloop.m
//  rongxin4
//
//  Created by eagle on 2019/6/18.
//  Copyright © 2019 yongzhen. All rights reserved.
//
// 卡顿检测类
#import "YZMonitorRunloop.h"
#import <execinfo.h>
#import "YZCallStack.h"
#import "YZAppInfoUtil.h"
#import "YZLogFile.h"
/**
 原理：利用观察Runloop各种状态变化的持续时间来检测计算是否发生卡顿
 一次有效卡顿采用了“N次卡顿超过阈值T”的判定策略，即一个时间段内卡顿的次数累计大于N时才触发采集和上报：举例，卡顿阈值T=500ms、卡顿次数N=1，可以判定为单次耗时较长的一次有效卡顿；而卡顿阈值T=50ms、卡顿次数N=5，可以判定为频次较快的一次有效卡顿
 */

// minimum
static const NSInteger MXRMonitorRunloopMinOneStandstillMillisecond = 20;
static const NSInteger MXRMonitorRunloopMinStandstillCount = 1;

// default
// 超过多少毫秒为一次卡顿
static const NSInteger MXRMonitorRunloopOneStandstillMillisecond = 50;
// 多少次卡顿纪录为一次有效卡顿
static const NSInteger MXRMonitorRunloopStandstillCount = 1;

@interface YZMonitorRunloop(){
    CFRunLoopObserverRef _observer;  // 观察者
    dispatch_semaphore_t _semaphore; // 信号量
    CFRunLoopActivity _activity;     // 状态
}

@property (nonatomic, assign) BOOL isCancel; //f是否取消检测
@property (nonatomic, assign) NSInteger countTime; // 耗时次数
@property (nonatomic, strong) NSMutableArray *backtrace;

@end


@implementation YZMonitorRunloop
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static YZMonitorRunloop *cls;
    dispatch_once(&onceToken, ^{
        cls = [[[self class] alloc] init];
        cls.limitMillisecond = MXRMonitorRunloopOneStandstillMillisecond;
        cls.standstillCount  = MXRMonitorRunloopStandstillCount;
    });
    return cls;
}

//重写set方法，用KVO监听
- (void)setLimitMillisecond:(int)limitMillisecond{
    [self willChangeValueForKey:@"limitMillisecond"];
    _limitMillisecond = limitMillisecond >= MXRMonitorRunloopMinOneStandstillMillisecond ? limitMillisecond : MXRMonitorRunloopMinOneStandstillMillisecond;
    [self didChangeValueForKey:@"limitMillisecond"];
}
- (void)setStandstillCount:(int)standstillCount
{
    [self willChangeValueForKey:@"standstillCount"];
    _standstillCount = standstillCount >= MXRMonitorRunloopMinStandstillCount ? standstillCount : MXRMonitorRunloopMinStandstillCount;
    [self didChangeValueForKey:@"standstillCount"];
}
//开始检测
- (void)startMonitor
{
    self.isCancel = NO;
    [self registerObserver];
}
//结束检测
- (void) endMonitor
{
    self.isCancel = YES;
    if(!_observer) return;
    //    将observer从当前thread的runloop中移除
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    //    释放 observer
    CFRelease(_observer);
    _observer = NULL;
}
//为了保证子线程的同步监测，刚开始创建一个信号量是0的dispatch_semaphore。当监测到主线程的RunLoop，触发回调
static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    if (activity != kCFRunLoopBeforeWaiting) {
        //        NSLog(@"-%s-- activity == %lu",__func__,activity);
    }
    
    YZMonitorRunloop *instance = [YZMonitorRunloop sharedInstance];
    // 记录状态值
    instance->_activity = activity;
    // 发送信号
    dispatch_semaphore_t semaphore = instance->_semaphore;
    //发送信号，使信号量+1
    dispatch_semaphore_signal(semaphore);
}

-(void)registerObserver{
    //    1. 设置Runloop observer的运行环境
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};
    // 2. 创建Runloop observer对象
    
    //    第一个参数：用于分配observer对象的内存
    //    第二个参数：用以设置observer所要关注的事件
    //    第三个参数：用于标识该observer是在第一次进入runloop时执行还是每次进入runloop处理时均执行
    //    第四个参数：用于设置该observer的优先级
    //    第五个参数：用于设置该observer的回调函数
    //    第六个参数：用于设置该observer的运行环境
    _observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                        kCFRunLoopAllActivities,
                                        YES,
                                        0,
                                        &runLoopObserverCallBack,
                                        &context);
    // 3. 将新建的observer加入到当前thread的runloop
    CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    // 创建信号  dispatchSemaphore的知识参考：https://www.jianshu.com/p/24ffa819379c
    _semaphore = dispatch_semaphore_create(0); ////Dispatch Semaphore保证同步
    
    __weak __typeof(self) weakSelf = self;
    
    //    dispatch_queue_t queue = dispatch_queue_create("kadun", NULL);
    
    // 在子线程监控时长
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        //      dispatch_async(queue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        while (YES) {
            if (strongSelf.isCancel) {
                return;
            }
            // N次卡顿超过阈值T记录为一次卡顿
            // 等待信号量：如果信号量是0，则阻塞当前线程；如果信号量大于0，则此函数会把信号量-1，继续执行线程。此处超时时间设为limitMillisecond 毫秒。
            // 返回值：如果线程是唤醒的，则返回非0，否则返回0
            long semaphoreWait = dispatch_semaphore_wait(self->_semaphore, dispatch_time(DISPATCH_TIME_NOW, strongSelf.limitMillisecond * NSEC_PER_MSEC));
            
            if (semaphoreWait != 0) {
                
                // 如果 RunLoop 的线程，进入睡眠前方法的执行时间过长而导致无法进入睡眠(kCFRunLoopBeforeSources)，或者线程唤醒后接收消息时间过长(kCFRunLoopAfterWaiting)而无法进入下一步的话，就可以认为是线程受阻。
                //两个runloop的状态，BeforeSources和AfterWaiting这两个状态区间时间能够监测到是否卡顿
                if (self->_activity == kCFRunLoopBeforeSources || self->_activity == kCFRunLoopAfterWaiting) {
                    
                    if (++strongSelf.countTime < strongSelf.standstillCount){
                        NSLog(@"%ld",strongSelf.countTime);
                        continue;
                    }
                    [strongSelf logStack];
                    [strongSelf printLogTrace];
                    
                    NSString *backtrace = [YZCallStack yz_backtraceOfMainThread];
                    NSLog(@"++++%@",backtrace);
                    
                    [[YZLogFile sharedInstance] writefile:backtrace];
                    
                    if (strongSelf.callbackWhenStandStill) {
                        strongSelf.callbackWhenStandStill();
                    }
                }
            }
            strongSelf.countTime = 0;
        }
    });
}



- (void)logStack
{
    NSLog(@"-%s--",__func__);
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    int i;
    _backtrace = [NSMutableArray arrayWithCapacity:frames];
    for ( i = 0 ; i < frames ; i++ ){
        [_backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
}

- (void)printLogTrace{
    NSLog(@"==========检测到卡顿之后调用堆栈==========\n %@ \n",_backtrace);
}


@end
