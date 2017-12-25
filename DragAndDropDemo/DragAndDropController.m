//
//  DragAndDropController.m
//  DragAndDropDemo
//
//  Created by LinChanglong on 2017/12/22.
//  Copyright © 2017年 linchl. All rights reserved.
//

#import "DragAndDropController.h"
#import <Masonry.h>
#import "ProviderReadItem.h"
#import "ProviderReadVideo.h"
#import "ProviderReadFolder.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "DocUtils.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

#define UI_COLOR(r,g,b) [UIColor colorWithRed:r/255.f green:g/255.f blue:b/255.f alpha:1.0]
// 单个附件大小上限（200M）
#define MAX_ATTACHEMT_SIZE          (200 * 1024 * 1024)
#define ICON_WIDTH                  40
#define ICON_HEIGHT                 40
#define FILE_VIEW_WIDTH             240
#define FILE_VIEW_HEIGHT            50
#define MARGIN                      5

typedef void(^YNItemProviderDealAction)(NSItemProvider *provider);

@interface DragAndDropController () <UIDragInteractionDelegate, UIDropInteractionDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, assign) UIView *preView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *topLabel;
@end

@implementation DragAndDropController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configViews];
    [self enableDrop];
}

- (UIScrollView *)scrollView {
    if (_scrollView == NULL) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.backgroundColor = self.view.backgroundColor;
        _scrollView.alwaysBounceVertical = YES;
        _scrollView.showsVerticalScrollIndicator = YES;
        if (@available(iOS 11.0, *)) {
            self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        [self.view addSubview:_scrollView];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
        tap.delegate = self;
        [self.scrollView addGestureRecognizer:tap];
    }
    return _scrollView;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    CGFloat height = 0;
    for (UIView *subView in self.contentView.subviews) {
        if ([subView isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subView;
            height += [label sizeThatFits:CGSizeMake(size.width - 2 * MARGIN, CGFLOAT_MAX)].height;
        } else {
            height += subView.frame.size.height;
        }
        height += MARGIN;
    }
    self.scrollView.contentSize = CGSizeMake(0, height);
}

- (UIView *)contentView {
    if (_contentView == NULL) {
        _contentView = [[UIView alloc] init];
        _contentView.backgroundColor = self.view.backgroundColor;
        [self.scrollView addSubview:_contentView];
    }
    return _contentView;
}

- (UILabel *)topLabel {
    if (_topLabel == NULL) {
        _topLabel = [[UILabel alloc] init];
        [_topLabel setText:@"请拖入文字、图片、视频或文件"];
        [_topLabel setTextColor:[UIColor blueColor]];
        [_topLabel setFont:[UIFont systemFontOfSize:18.0f]];
        _topLabel.numberOfLines = 0;
        _topLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [self.contentView addSubview:_topLabel];
    }
    return _topLabel;
}

- (UIView *)preView {
    if (_preView == NULL) {
        _preView = self.topLabel;
    }
    return _preView;
}

- (void)configViews {
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.left.right.bottom.mas_equalTo(0);
    }];
    
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(0);
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.width.equalTo(self.view);
        make.bottom.equalTo(self.preView.mas_bottom);
    }];
    
    [self.topLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(MARGIN);
        make.left.mas_equalTo(MARGIN);
        make.right.mas_equalTo(-MARGIN);
    }];
}

- (NSString *)pathExtensionFromUTI:(NSString *)uti {
    CFStringRef theUTI = (__bridge CFStringRef)uti;
    CFStringRef results = UTTypeCopyPreferredTagWithClass(theUTI, kUTTagClassFilenameExtension);
    return (__bridge_transfer NSString *)results;
}

- (NSURL *)writeFile:(ProviderRead *)file fileName:(NSString *)fileName {
    NSString *resID = [self genID];
    NSString *docPath = [self getDocumentPath:resID];
    NSString *docFile = [docPath stringByAppendingPathComponent:fileName];
    [file.data writeToFile:docFile atomically:YES];
    return [NSURL fileURLWithPath:docFile];
}

- (NSString *)genID {
    long long interval = [[NSDate date] timeIntervalSince1970] * 1000000;
    NSString *resID = [NSString stringWithFormat:@"%d%lld", arc4random() % 1000, interval];
    return resID;
}

- (NSString *)getDocumentPath:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *localDir = [paths objectAtIndex:0];
    NSString *filePath = [localDir stringByAppendingPathComponent:fileName];
    return filePath;
}

- (void)dropView:(UIView *)view withHeight:(CGFloat)height {
    [self.contentView addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.preView.mas_bottom).offset(10);
        make.left.mas_equalTo(10);
        if ([view isKindOfClass:[UIImageView class]]) {
            UIImageView *imageView = (UIImageView *)view;
            make.size.mas_equalTo(imageView.image.size);
        } else if ([view isKindOfClass:[UILabel class]]) {
            make.right.mas_equalTo(-MARGIN);
        } else {
            make.width.mas_equalTo(FILE_VIEW_WIDTH);
            make.height.mas_equalTo(FILE_VIEW_HEIGHT);
        }
    }];
    [self.contentView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(0);
        make.top.mas_equalTo(0);
        make.width.equalTo(self.view);
        make.bottom.equalTo(view.mas_bottom);
    }];
    self.scrollView.contentSize = CGSizeMake(self.contentView.frame.size.width, self.contentView.frame.size.height + MARGIN + height);
    self.preView = view;
}
- (void)enableDrop {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"11.0")) {
        if (@available(iOS 11.0, *)) {
            UIDropInteraction* drop = [[UIDropInteraction alloc] initWithDelegate:self];
            [self.scrollView addInteraction:drop];
        }
    }
}

#pragma mark - UIDropInteractionDelegate
- (BOOL)dropInteraction:(UIDropInteraction *)interaction canHandleSession:(id<UIDropSession>)session
{
    if (session.localDragSession != nil) { //ignore drag session started within app
        return false;
    }
    if ([[session items] count] > 10) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"上传失败" message:@"一次最多上传10个文件" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:closeAction];
        [self presentViewController:alertController animated:YES completion:nil];
        return false;
    }
    BOOL canHandle = false;
    if ([[session items] count] == 1 && [session canLoadObjectsOfClass:[ProviderReadFolder class]]) {
        canHandle = false;
    } else {
        canHandle = [session canLoadObjectsOfClass:[ProviderReadVideo class]] || [session canLoadObjectsOfClass:[ProviderReadItem class]] || [session canLoadObjectsOfClass:[UIImage class]] || [session canLoadObjectsOfClass:[NSString class]];
    }
    return canHandle;
}

- (UIDropProposal *)dropInteraction:(UIDropInteraction *)interaction sessionDidUpdate:(id<UIDropSession>)session
{
    if (@available(iOS 11.0, *)) {
        return [[UIDropProposal alloc] initWithDropOperation:UIDropOperationCopy];
    }
    return nil;
}

- (void)dropInteraction:(UIDropInteraction *)interaction performDrop:(id<UIDropSession>)session
{
    uint64_t masSize = MAX_ATTACHEMT_SIZE;

    __block BOOL hasAlert = NO;
    for (UIDragItem *item in [session items]) {
        __block NSItemProvider *provider = [item itemProvider];
        if (@available(iOS 11.0, *)) {
            YNItemProviderDealAction fileAction = ^(NSItemProvider *provider) {
                [provider loadFileRepresentationForTypeIdentifier:[provider registeredTypeIdentifiers][0] completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                    if (url) {
                        uint64_t recordSizeByBytes = [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:nil] ? [[[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:nil][NSFileSize] longLongValue] : 0;
                        if (recordSizeByBytes <= masSize) {
                            __block NSString *fileName = [url lastPathComponent];
                            if (fileName.length > 0 && fileName.pathExtension.length <= 0) {
                                for (NSString *uti in provider.registeredTypeIdentifiers) {
                                    NSString *extension = [self pathExtensionFromUTI:uti];
                                    if (extension && extension.length > 0) {
                                        fileName = [fileName stringByAppendingPathExtension:extension];
                                        break;
                                    }
                                }
                            }

                            [provider loadObjectOfClass:[ProviderReadItem class] completionHandler:^(id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
                                if (!error) {
                                    ProviderReadItem *item = (ProviderReadItem *)object;
                                    if (item) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            NSURL *url = [self writeFile:item fileName:fileName];
                                            UIView *view = [[UIView alloc] init];
                                            view.backgroundColor = UI_COLOR(242, 243, 244);
                                            NSString *imageName = [DocUtils getDragIconByTitle:fileName];
                                            UIImageView *fileIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:imageName]];
                                            [view addSubview:fileIcon];
                                            
                                            UILabel *label = [[UILabel alloc] init];
                                            [label setText:fileName];
                                            [label setTextColor:[UIColor grayColor]];
                                            [label setFont:[UIFont systemFontOfSize:13.0f]];
                                            [view addSubview:label];
                                            
                                            [label mas_makeConstraints:^(MASConstraintMaker *make) {
                                                make.left.mas_equalTo(fileIcon.mas_right).offset(MARGIN);
                                                make.centerY.equalTo(view);
                                                make.right.equalTo(view).offset(-MARGIN);
                                            }];
                                            
                                            [fileIcon mas_makeConstraints:^(MASConstraintMaker *make) {
                                                make.width.mas_equalTo(ICON_WIDTH);
                                                make.height.mas_equalTo(ICON_HEIGHT);
                                                make.centerY.equalTo(view);
                                                make.left.mas_equalTo(MARGIN);
                                            }];
                                            
                                            [self dropView:view withHeight:FILE_VIEW_HEIGHT];
                                        });
                                    }
                                }
                            }];
                        } else if (!hasAlert) {
                            hasAlert = YES;
                            NSString *errMsg = @"无法上传大于200M的文件";
                            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"上传失败" message:errMsg preferredStyle:UIAlertControllerStyleAlert];
                            UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil];
                            [alertController addAction:closeAction];
                            [self presentViewController:alertController animated:YES completion:nil];
                        }
                    }
                }];
            };
            YNItemProviderDealAction imageAction = ^(NSItemProvider *provider) {
                [provider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
                    UIImage* image = (UIImage*)object;
                    if (image) {
                        //handle image
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                            [self dropView:imageView withHeight:image.size.height];
                        });
                    } else {
                        fileAction(provider);
                    }
                }];
            };
            YNItemProviderDealAction stringAction = ^(NSItemProvider *provider) {
                [provider loadObjectOfClass:[NSString class] completionHandler:^(id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
                    NSString *str = (NSString*)object;
                    if (str) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UILabel *label = [[UILabel alloc] init];
                            [label setText:str];
                            [label setFont:[UIFont systemFontOfSize:15.0f]];
                            [label setTextColor:[UIColor blackColor]];
                            label.numberOfLines = 0;
                            label.lineBreakMode = NSLineBreakByWordWrapping;
                            CGSize labelSize = [label sizeThatFits:CGSizeMake(self.view.frame.size.width - 2 * MARGIN, CGFLOAT_MAX)];
                            [self dropView:label withHeight:labelSize.height];
                        });
                    } else {
                        fileAction(provider);
                    }
                }];
            };
            if ([provider canLoadObjectOfClass:[UIImage class]]) {
                imageAction(provider);
            } else if ([provider canLoadObjectOfClass:[NSString class]]) {
                stringAction(provider);
            } else if (![provider canLoadObjectOfClass:[ProviderReadFolder class]] && [provider canLoadObjectOfClass:[ProviderReadItem class]]) {
                fileAction(provider);
            }
        }
    }
}

@end
