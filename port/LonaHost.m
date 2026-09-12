#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>

#include <math.h>
#include "app_bridge.h"

static const CGFloat kControlAlpha = 0.76;

@interface LonaKeyButton : UIControl
@property(nonatomic) int scancode;
@property(nonatomic,strong) UILabel *labelView;
@property(nonatomic,strong) UIVisualEffectView *glass;
@property(nonatomic) BOOL keyDown;
- (instancetype)initWithLabel:(NSString *)label scancode:(int)scancode;
@end

@implementation LonaKeyButton
- (instancetype)initWithLabel:(NSString *)label scancode:(int)scancode {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.scancode = scancode;
        self.multipleTouchEnabled = NO;
        self.layer.cornerRadius = 18;
        self.layer.masksToBounds = YES;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        _glass = [[UIVisualEffectView alloc] initWithEffect:blur];
        _glass.userInteractionEnabled = NO;
        _glass.alpha = kControlAlpha;
        [self addSubview:_glass];

        _labelView = [[UILabel alloc] initWithFrame:CGRectZero];
        _labelView.text = label;
        _labelView.textAlignment = NSTextAlignmentCenter;
        _labelView.textColor = UIColor.whiteColor;
        _labelView.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _labelView.adjustsFontSizeToFitWidth = YES;
        _labelView.minimumScaleFactor = 0.65;
        [self addSubview:_labelView];

        [self addTarget:self action:@selector(pressDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(pressUp) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.glass.frame = self.bounds;
    self.labelView.frame = CGRectInset(self.bounds, 4, 4);
}
- (void)pressDown {
    if (self.keyDown) return;
    self.keyDown = YES;
    mkxp_injectKeyEvent(self.scancode, 1);
    [UIView animateWithDuration:0.06 animations:^{ self.transform = CGAffineTransformMakeScale(0.92, 0.92); self.glass.alpha = 0.95; }];
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [g impactOccurred];
    }
}
- (void)pressUp {
    if (!self.keyDown) return;
    self.keyDown = NO;
    mkxp_injectKeyEvent(self.scancode, 0);
    [UIView animateWithDuration:0.08 animations:^{ self.transform = CGAffineTransformIdentity; self.glass.alpha = kControlAlpha; }];
}
@end

@interface LonaDPad : UIView
@property(nonatomic) int activeScancode;
@property(nonatomic,strong) UIView *base;
@property(nonatomic,strong) UIView *nub;
@end

@implementation LonaDPad
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.multipleTouchEnabled = NO;
        self.activeScancode = MKXP_SCANCODE_UNKNOWN;
        _base = [[UIView alloc] initWithFrame:CGRectZero];
        _base.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.46];
        _base.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.13].CGColor;
        _base.layer.borderWidth = 1.0;
        [self addSubview:_base];
        _nub = [[UIView alloc] initWithFrame:CGRectZero];
        _nub.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
        [self addSubview:_nub];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat side = MIN(self.bounds.size.width, self.bounds.size.height);
    self.base.frame = CGRectMake((self.bounds.size.width-side)/2,(self.bounds.size.height-side)/2,side,side);
    self.base.layer.cornerRadius = side/2;
    CGFloat nub = side * 0.38;
    self.nub.bounds = CGRectMake(0,0,nub,nub);
    self.nub.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    self.nub.layer.cornerRadius = nub/2;
}
- (int)scancodeForPoint:(CGPoint)p {
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat dx=p.x-c.x, dy=p.y-c.y;
    if (hypot(dx,dy) < MIN(self.bounds.size.width,self.bounds.size.height)*0.16) return MKXP_SCANCODE_UNKNOWN;
    if (fabs(dx) > fabs(dy)) return dx < 0 ? MKXP_SCANCODE_LEFT : MKXP_SCANCODE_RIGHT;
    return dy < 0 ? MKXP_SCANCODE_UP : MKXP_SCANCODE_DOWN;
}
- (void)update:(UITouch *)touch {
    CGPoint p=[touch locationInView:self];
    int next=[self scancodeForPoint:p];
    if (next == self.activeScancode) return;
    if (self.activeScancode != MKXP_SCANCODE_UNKNOWN) mkxp_injectKeyEvent(self.activeScancode,0);
    self.activeScancode=next;
    if (next != MKXP_SCANCODE_UNKNOWN) mkxp_injectKeyEvent(next,1);
    CGPoint c=CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));
    CGFloat dx=p.x-c.x, dy=p.y-c.y;
    CGFloat maxR=MIN(self.bounds.size.width,self.bounds.size.height)*0.22;
    CGFloat len=hypot(dx,dy); if (len>maxR && len>0) { dx=dx/len*maxR; dy=dy/len*maxR; }
    [UIView animateWithDuration:0.04 animations:^{ self.nub.center=CGPointMake(c.x+dx,c.y+dy); }];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self update:touches.anyObject]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self update:touches.anyObject]; }
- (void)endTouch {
    if (self.activeScancode != MKXP_SCANCODE_UNKNOWN) mkxp_injectKeyEvent(self.activeScancode,0);
    self.activeScancode=MKXP_SCANCODE_UNKNOWN;
    [UIView animateWithDuration:0.08 animations:^{ self.nub.center=CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds)); }];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self endTouch]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self endTouch]; }
@end

@interface LonaOverlayView : UIView
@property(nonatomic,strong) LonaDPad *dpad;
@property(nonatomic,strong) NSMutableArray<LonaKeyButton *> *buttons;
@end

@implementation LonaOverlayView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.clearColor;
        self.multipleTouchEnabled=YES;
        self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        _buttons=[NSMutableArray array];
        _dpad=[[LonaDPad alloc] initWithFrame:CGRectZero];
        [self addSubview:_dpad];

        [self addButton:@"ACT" key:MKXP_SCANCODE_RETURN];
        [self addButton:@"MENU" key:MKXP_SCANCODE_ESCAPE];
        [self addButton:@"ATK" key:MKXP_SCANCODE_Z];
        [self addButton:@"HEAVY" key:MKXP_SCANCODE_X];
        [self addButton:@"S3" key:MKXP_SCANCODE_C];
        [self addButton:@"RUN" key:MKXP_SCANCODE_LSHIFT];
        [self addButton:@"S4" key:MKXP_SCANCODE_A];
        [self addButton:@"S5" key:MKXP_SCANCODE_S];
        [self addButton:@"S6" key:MKXP_SCANCODE_D];
        [self addButton:@"S7" key:MKXP_SCANCODE_F];
        [self addButton:@"S8" key:MKXP_SCANCODE_G];
        [self addButton:@"ITEM" key:MKXP_SCANCODE_LCTRL];
        [self addButton:@"PREV" key:MKXP_SCANCODE_Q];
        [self addButton:@"NEXT" key:MKXP_SCANCODE_W];
        [self addButton:@"WAIT" key:MKXP_SCANCODE_SPACE];
        [self addButton:@"VIEW" key:MKXP_SCANCODE_LALT];
    }
    return self;
}
- (void)addButton:(NSString *)label key:(int)key {
    LonaKeyButton *b=[[LonaKeyButton alloc] initWithLabel:label scancode:key];
    [self.buttons addObject:b]; [self addSubview:b];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIEdgeInsets s=self.safeAreaInsets;
    CGFloat W=self.bounds.size.width, H=self.bounds.size.height;
    BOOL land=W>H;
    CGFloat d=land?150:142;
    self.dpad.frame=CGRectMake(s.left+22,H-s.bottom-d-26,d,d);

    CGFloat big=land?66:62, mid=land?56:52, small=land?46:44;
    CGFloat right=W-s.right-24;
    CGFloat bottom=H-s.bottom-24;
    NSArray<NSValue *> *frames=@[
      [NSValue valueWithCGRect:CGRectMake(right-big,bottom-big,big,big)],
      [NSValue valueWithCGRect:CGRectMake(right-big-mid-12,bottom-mid+2,mid,mid)],
      [NSValue valueWithCGRect:CGRectMake(right-big,bottom-big-mid-12,mid,mid)],
      [NSValue valueWithCGRect:CGRectMake(right-big-mid-12,bottom-mid-mid-10,mid,mid)],
      [NSValue valueWithCGRect:CGRectMake(right-big-mid*2-24,bottom-mid-mid-10,mid,mid)],
      [NSValue valueWithCGRect:CGRectMake(right-big-mid*2-24,bottom-mid+2,mid,mid)],
      [NSValue valueWithCGRect:CGRectMake(right-small,bottom-big-mid-small-24,small,small)],
      [NSValue valueWithCGRect:CGRectMake(right-small*2-8,bottom-big-mid-small-24,small,small)],
      [NSValue valueWithCGRect:CGRectMake(right-small*3-16,bottom-big-mid-small-24,small,small)],
      [NSValue valueWithCGRect:CGRectMake(right-small*4-24,bottom-big-mid-small-24,small,small)],
      [NSValue valueWithCGRect:CGRectMake(right-small*5-32,bottom-big-mid-small-24,small,small)],
      [NSValue valueWithCGRect:CGRectMake(right-small*6-40,bottom-big-mid-small-24,small,small)],
      [NSValue valueWithCGRect:CGRectMake(s.left+18,s.top+18,small,small)],
      [NSValue valueWithCGRect:CGRectMake(s.left+18+small+8,s.top+18,small,small)],
      [NSValue valueWithCGRect:CGRectMake(s.left+18,s.top+18+small+8,small,small)],
      [NSValue valueWithCGRect:CGRectMake(s.left+18+small+8,s.top+18+small+8,small,small)]
    ];
    for (NSUInteger i=0;i<self.buttons.count && i<frames.count;i++) self.buttons[i].frame=frames[i].CGRectValue;
}
@end

static LonaOverlayView *gOverlay;

static UIWindow *findGameWindow(void) {
    void *raw = mkxp_getSDLUIKitWindow();
    if (raw) return (__bridge UIWindow *)raw;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) if (!w.hidden) return w;
    }
    return nil;
}

static void installOverlay(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window=findGameWindow(); if (!window) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{installOverlay();}); return; }
        if (!gOverlay) gOverlay=[[LonaOverlayView alloc] initWithFrame:window.bounds];
        gOverlay.frame=window.bounds;
        if (gOverlay.superview != window) { [gOverlay removeFromSuperview]; [window addSubview:gOverlay]; }
        [window bringSubviewToFront:gOverlay];
    });
}

static void lonaFrameRendered(void *u) { installOverlay(); }
static void lonaRectChanged(float x,float y,float w,float h,void *u) { installOverlay(); }

static void showMessage(NSString *text, BOOL error) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window=findGameWindow();
        UIViewController *vc=window.rootViewController;
        while (vc.presentedViewController) vc=vc.presentedViewController;
        if (!vc) { if(error) mkxp_signalErrorDismissed(); else mkxp_signalInfoDismissed(); return; }
        UIAlertController *a=[UIAlertController alertControllerWithTitle:error?@"Lona":@"Lona" message:text preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){ if(error) mkxp_signalErrorDismissed(); else mkxp_signalInfoDismissed(); }]];
        [vc presentViewController:a animated:YES completion:nil];
    });
}
static void lonaErrorMessage(const char *m, void *u) { showMessage(m?@(m):@"Unknown error",YES); }
static void lonaInfoMessage(const char *m, void *u) { showMessage(m?@(m):@"",NO); }

static NSString *prepareGame(void) {
    NSFileManager *fm=NSFileManager.defaultManager;
    NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    NSString *target=[docs stringByAppendingPathComponent:@"LonaGame"];
    NSString *source=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Game"];
    NSString *sourceVersion=[source stringByAppendingPathComponent:@".lona_payload_version"];
    NSString *targetVersion=[target stringByAppendingPathComponent:@".lona_payload_version"];
    NSString *sv=[NSString stringWithContentsOfFile:sourceVersion encoding:NSUTF8StringEncoding error:nil];
    NSString *tv=[NSString stringWithContentsOfFile:targetVersion encoding:NSUTF8StringEncoding error:nil];
    BOOL valid=[fm fileExistsAtPath:[target stringByAppendingPathComponent:@"Game.ini"]];
    if (!valid || (sv && ![sv isEqualToString:tv])) {
        [fm removeItemAtPath:target error:nil];
        NSError *err=nil;
        if (![fm copyItemAtPath:source toPath:target error:&err]) { NSLog(@"[lona] game copy failed: %@",err); return source; }
    }
    return target;
}

static void lonaStart(void) {
    @autoreleasepool {
        NSString *resources=NSBundle.mainBundle.resourcePath;
        NSString *game=prepareGame();
        NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
        NSString *userdata=[docs stringByAppendingPathComponent:@"LonaUserData"];
        [NSFileManager.defaultManager createDirectoryAtPath:userdata withIntermediateDirectories:YES attributes:nil error:nil];

        mkxp_setActiveRubyVersion(MKXP_RUBY_19);
        mkxp_applyPerGameSettings(MKXP_VALIGN_CENTER,true);
        mkxp_setNetworkEnabled(false);
        mkxp_setTouchMouseEnabled(false);
        mkxp_setErrorMessageCallback(lonaErrorMessage,NULL);
        mkxp_setInfoMessageCallback(lonaInfoMessage,NULL);
        mkxp_setFrameRenderedCallback(lonaFrameRendered,NULL);
        mkxp_setGameRectChangedCallback(lonaRectChanged,NULL);
        mkxp_setLauncherIdentity("lona_ios");
        mkxp_setUserDataDirectory(userdata.fileSystemRepresentation);
        mkxp_setSharedFontsDirectory([resources stringByAppendingPathComponent:@"Assets.bundle/Fonts"].fileSystemRepresentation);
        mkxp_setCABundlePath([resources stringByAppendingPathComponent:@"Assets.bundle/cacert.pem"].fileSystemRepresentation);
        mkxp_setManagedConfigDir(game.fileSystemRepresentation);
        mkxp_setGamePath(game.fileSystemRepresentation);
        installOverlay();
    }
}

__attribute__((constructor)) static void lonaInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ lonaStart(); });
}
