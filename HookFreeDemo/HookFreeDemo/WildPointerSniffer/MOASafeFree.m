
//
//  MOASafeFree.m
//  MOAZombieSniffer
//
//  Created by fjf on 2018/7/30.
//  Copyright © 2018年 fjf. All rights reserved.
//

#import "queue.h"
#import "fishhook.h"
#import "MOACatcher.h"
#import "MOASafeFree.h"
#import <dlfcn.h>
#include <objc/runtime.h>
#include <malloc/malloc.h>

static Class sYHCatchIsa;
static size_t sYHCatchSize;

static void(* orig_free)(void *p);
static CFMutableSetRef registeredClasses = nil;
struct DSQueue* _unfreeQueue = NULL;//用来保存自己偷偷保留的内存:1这个队列要线程安全或者自己加锁;2这个队列内部应该尽量少申请和释放堆内存。
int unfreeSize = 0;//用来记录我们偷偷保存的内存的大小
#define MAX_STEAL_MEM_SIZE 1024*1024*100//最多存这么多内存，大于这个值就释放一部分
#define MAX_STEAL_MEM_NUM 1024*1024*10//最多保留这么多个指针，再多就释放一部分
#define BATCH_FREE_NUM 100//每次释放的时候释放指针数量

@implementation MOASafeFree

#pragma mark -------------------------- Life  Circle
+ (void)load{
#ifdef DEBUG
    loadCatchProxyClass();
    init_safe_free();
#endif
}

#pragma mark -------------------------- Public  Methods
//系统内存警告的时候调用这个函数释放一些内存
void free_some_mem(size_t freeNum){
#ifdef DEBUG
    size_t count = ds_queue_length(_unfreeQueue);
    freeNum= freeNum > count ? count:freeNum;
    for (int i=0; i<freeNum; i++) {
        // 从队列获取未释放的指针
        void *unfreePoint = ds_queue_get(_unfreeQueue);
        // 获取指针指向的内存大小
        size_t memSiziee = malloc_size(unfreePoint);
        // 修改当前未释放内存大小（原子减操作）
        __sync_fetch_and_sub(&unfreeSize, (int)memSiziee);
        // 调用系统的free函数释放内存
        orig_free(unfreePoint);
    }
#endif
}

#pragma mark -------------------------- Private  Methods

// 自定义的free函数
void safe_free(void* p){
    
    int unFreeCount = ds_queue_length(_unfreeQueue);
    // 保留的内存大于一定值的时候就释放一部分
    if (unFreeCount > MAX_STEAL_MEM_NUM*0.9 || unfreeSize>MAX_STEAL_MEM_SIZE) {
        free_some_mem(BATCH_FREE_NUM);
    } else {
        size_t memSiziee = malloc_size(p);
        if (memSiziee > sYHCatchSize) {//有足够的空间才覆盖
            id obj=(id)p;
            Class origClass= object_getClass(obj);
            // 判断是不是objc对象
            char *type = @encode(typeof(obj));
            if (strcmp("@", type) == 0 && CFSetContainsValue(registeredClasses, origClass)) {
                memset(obj, 0x55, memSiziee);
                // 修改原来类的isa指针
                memcpy(obj, &sYHCatchIsa, sizeof(void*));
                object_setClass(obj, [MOACatcher class]);
                ((MOACatcher *)obj).originClass = origClass;
                // 多线程下int的原子加操作,多线程对全局变量进行自加，不用理线程锁了
                __sync_fetch_and_add(&unfreeSize,(int)memSiziee);
                // 入队
                ds_queue_put(_unfreeQueue, p);
            }else{
               orig_free(p);
            }
        } else {
           orig_free(p);
        }
    }
}

void loadCatchProxyClass() {
    registeredClasses = CFSetCreateMutable(NULL, 0, NULL);

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    for (unsigned int i = 0; i < count; i++) {
    CFSetAddValue(registeredClasses, (__bridge const void *)(classes[i]));
    }
    free(classes);
    classes = NULL;
    
    sYHCatchIsa = objc_getClass("MOACatcher");
    sYHCatchSize = class_getInstanceSize(sYHCatchIsa);
}

// 初始化
bool init_safe_free() {
    // 初始化存放延迟释放对象的队列
    _unfreeQueue = ds_queue_create(MAX_STEAL_MEM_NUM);
    // hook free函数
    orig_free = (void(*)(void*))dlsym(RTLD_DEFAULT, "free");
    rebind_symbols((struct rebinding[]){{"free", (void*)safe_free}}, 1);
    
    return true;
}

@end
