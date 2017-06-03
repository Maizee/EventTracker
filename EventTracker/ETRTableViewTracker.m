//
//  ETRTableViewTracker.m
//  EventTracker
//
//  Created by Maize on 2017/6/2.
//  Copyright © 2017年 maize.com. All rights reserved.
//

#import "ETRTableViewTracker.h"
#import "ETRTableViewFakeDelegate.h"
#import "UITableView+ETRTracker.h"

#import <objc/runtime.h>

static NSString *kETRTableViewFakeDelegatePrefix = @"etr_tableViewFakeDelegate";

@interface ETRTableViewTracker ()

@property (nonatomic, weak) UITableView *tableView;

@end

@implementation ETRTableViewTracker

+ (ETRTableViewTracker *)startTrackWithHostTableView:(UITableView *)tableView
{
    ETRTableViewTracker *tracker = [[ETRTableViewTracker alloc] init];
    tracker.tableView = tableView;
    tableView.etr_tracker = tracker;
    
    id<UITableViewDelegate> delegate = tableView.delegate;
    if (delegate
        && ![NSStringFromClass([delegate class]) hasPrefix:kETRTableViewFakeDelegatePrefix]) {
        Class fakeDelegateClass = [self getTableViewFakeDelegateClass:[delegate class]];
        object_setClass(delegate, fakeDelegateClass);
        
        tableView.delegate = delegate;
    }
    [tableView addObserver:tracker forKeyPath:@"delegate" options:NSKeyValueObservingOptionNew context:nil];
    
    return tracker;
}

+ (Class)getTableViewFakeDelegateClass:(Class)originalClass
{
    NSString *fakeDelegateName = [kETRTableViewFakeDelegatePrefix stringByAppendingString:NSStringFromClass([originalClass class])];
    Class fakeDelegateClass = NSClassFromString(fakeDelegateName);
    
    if (!fakeDelegateClass) {
        fakeDelegateClass = objc_allocateClassPair(originalClass, fakeDelegateName.UTF8String, 0);
        
        Method classMethod = class_getInstanceMethod([ETRTableViewFakeDelegate class], @selector(class));
        class_addMethod(fakeDelegateClass, method_getName(classMethod), method_getImplementation(classMethod), method_getTypeEncoding(classMethod));
        
        classMethod = class_getInstanceMethod([ETRTableViewFakeDelegate class], @selector(respondsToSelector:));
        class_addMethod(fakeDelegateClass, method_getName(classMethod), method_getImplementation(classMethod), method_getTypeEncoding(classMethod));
        
        classMethod = class_getInstanceMethod([ETRTableViewFakeDelegate class], @selector(tableView:didSelectRowAtIndexPath:));
        class_addMethod(fakeDelegateClass, method_getName(classMethod), method_getImplementation(classMethod), method_getTypeEncoding(classMethod));
        
        classMethod = class_getInstanceMethod([ETRTableViewFakeDelegate class], @selector(tableView:willDisplayCell:forRowAtIndexPath:));
        class_addMethod(fakeDelegateClass, method_getName(classMethod), method_getImplementation(classMethod), method_getTypeEncoding(classMethod));
        
        objc_registerClassPair(fakeDelegateClass);
    }
    
    return fakeDelegateClass;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([object isKindOfClass:[UITableView class]]
        && [keyPath isEqualToString:@"delegate"]) {
        id<UITableViewDelegate> delegate = change[NSKeyValueChangeNewKey];
        if (delegate
            && ![delegate isKindOfClass:[NSNull class]]
            && ![NSStringFromClass([delegate class]) hasPrefix:kETRTableViewFakeDelegatePrefix]) {
            Class fakeDelegateClass = [ETRTableViewTracker getTableViewFakeDelegateClass:[delegate class]];
            object_setClass(delegate, fakeDelegateClass);
        }
        
        if ([delegate isKindOfClass:[NSObject class]]
            && [NSStringFromClass([delegate class]) hasPrefix:kETRTableViewFakeDelegatePrefix]) {
            ((NSObject *)delegate).etr_viewTrackEventHandler = self.viewHandler;
            ((NSObject *)delegate).etr_clickTrackEventHandler = self.clickHandler;
        }
    }
}

- (void)setViewHandler:(ETR_viewTrackEventHandler)viewHandler
{
    _viewHandler = [viewHandler copy];
    
    if ([self.tableView.delegate isKindOfClass:[NSObject class]]) {
        ((NSObject *)self.tableView.delegate).etr_viewTrackEventHandler = viewHandler;
    }
}

- (void)setClickHandler:(ETR_clickTrackEventHandler)clickHandler
{
    _clickHandler = clickHandler;
    
    if ([self.tableView.delegate isKindOfClass:[NSObject class]]) {
        ((NSObject *)self.tableView.delegate).etr_clickTrackEventHandler = clickHandler;
    }
}

@end
