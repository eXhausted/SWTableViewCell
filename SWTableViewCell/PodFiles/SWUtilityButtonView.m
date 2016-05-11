//
//  SWUtilityButtonView.m
//  SWTableViewCell
//
//  Created by Matt Bowman on 11/27/13.
//  Copyright (c) 2013 Chris Wendel. All rights reserved.
//

#import "SWUtilityButtonView.h"
#import "SWUtilityButtonTapGestureRecognizer.h"

NS_INLINE double bezier(double time, double A, double B, double C)
{
    return time * (C + time * (B + time * A)); //A t^3 + B t^2 + C t
}

NS_INLINE double bezier_der(double time, double A, double B, double C)
{
    return C + time * (2 * B + time * 3 * A); //3 A t^2 + 2 B t + C
}

NS_INLINE double kParametricAnimationLerpDouble(double progress, double from, double to) {
    return from + (to - from) * progress;
};

NS_INLINE double xForTime(double time, double ctx1, double ctx2)
{
    double x = time, z;
    
    double C = 3 * ctx1;
    double B = 3 * (ctx2 - ctx1) - C;
    double A = 1 - C - B;
    
    int i = 0;
    while (i < 5) {
        z = bezier(x, A, B, C) - time;
        if (fabs(z) < 0.001) break;
        
        x = x - z / bezier_der(x, A, B, C);
        i++;
    }
    
    return x;
}

NS_INLINE double ParametricAnimationBezierEvaluator(double time, CGPoint ct1, CGPoint ct2) {
    double Cy = 3 * ct1.y;
    double By = 3 * (ct2.y - ct1.y) - Cy;
    double Ay = 1 - Cy - By;
    
    return bezier(xForTime(time, ct1.x, ct2.x), Ay, By, Cy);
}

NS_INLINE double ParametricAnimationTimeBlockAppleIn(double time) {
    CGPoint ct1 = CGPointMake(0.42, 0.0), ct2 = CGPointMake(1.0, 1.0);
    return ParametricAnimationBezierEvaluator(time, ct1, ct2);
};

NS_INLINE double ParametricAnimationTimeBlockAppleOut(double time) {
    CGPoint ct1 = CGPointMake(0.0, 0.0), ct2 = CGPointMake(0.58, 1.0);
    return ParametricAnimationBezierEvaluator(time, ct1, ct2);
};

NS_INLINE double ParametricAnimationTimeBlockBackOut(double time) {
    CGPoint ct1 = CGPointMake(0.175, 0.885), ct2 = CGPointMake(0.32, 1.275);
    return ParametricAnimationBezierEvaluator(time, ct1, ct2);
}

NS_INLINE NSValue *valueFxn(double progress, id fromValue, id toValue) {
    NSValue *value;
    double from = [fromValue doubleValue], to = [toValue doubleValue];
    value = [NSNumber numberWithDouble:kParametricAnimationLerpDouble(progress, from, to)];
    return value;
}

NS_INLINE double timeFxn(double time) {
    return ParametricAnimationTimeBlockAppleIn(time);
}

@interface SWUtilityButtonView()

@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *edgeConstrains;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;
@property (nonatomic, strong) NSMutableArray *buttonBackgroundColors;
@property (nonatomic, assign) CGFloat buttonWidth;

@property (nonatomic, strong) NSArray *animationCurves;

@end

@implementation SWUtilityButtonView

#pragma mark - SWUtilityButonView initializers

- (id)initWithUtilityButtons:(NSArray *)utilityButtons parentCell:(SWTableViewCell *)parentCell utilityButtonSelector:(SEL)utilityButtonSelector
{
    self = [self initWithFrame:CGRectZero utilityButtons:utilityButtons parentCell:parentCell utilityButtonSelector:utilityButtonSelector];
    
    return self;
}

- (id)initWithFrame:(CGRect)frame utilityButtons:(NSArray *)utilityButtons parentCell:(SWTableViewCell *)parentCell utilityButtonSelector:(SEL)utilityButtonSelector
{
    self = [super initWithFrame:frame];
    
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        
        self.widthConstraint = [NSLayoutConstraint constraintWithItem:self
                                                            attribute:NSLayoutAttributeWidth
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:nil
                                                            attribute:NSLayoutAttributeNotAnAttribute
                                                           multiplier:1.0
                                                             constant:0.0]; // constant will be adjusted dynamically in -setUtilityButtons:.
        self.widthConstraint.priority = UILayoutPriorityDefaultHigh;
        [self addConstraint:self.widthConstraint];
        
        _parentCell = parentCell;
        self.utilityButtonSelector = utilityButtonSelector;
        self.utilityButtons = utilityButtons;
    }
    
    return self;
}

#pragma mark Populating utility buttons

- (void)setUtilityButtons:(NSArray *)utilityButtons
{
    // if no width specified, use the default width
    [self setUtilityButtons:utilityButtons WithButtonWidth:kUtilityButtonWidthDefault];
}

- (void)setUtilityButtons:(NSArray *)utilityButtons WithButtonWidth:(CGFloat)width
{
    self.buttonWidth = width;
    CGFloat selfWidth = (width * utilityButtons.count);
    
    for (UIButton *button in _utilityButtons)
    {
        [button removeFromSuperview];
    }
    
    _utilityButtons = [utilityButtons copy];
    
    if (utilityButtons.count)
    {
        NSUInteger utilityButtonsCounter = 0;
        UIView *precedingView = nil;
        CGFloat animationWidth = selfWidth;
        
        NSMutableArray *edgeConstraints = [NSMutableArray new];
        NSMutableArray *animationCurves = [NSMutableArray new];
        
        for (UIButton *button in _utilityButtons)
        {
            [self addSubview:button];
            button.translatesAutoresizingMaskIntoConstraints = NO;
            
            NSArray *edgeConstraint = [NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"H:[button]-(%f)-|", animationWidth]
                                                                              options:0L
                                                                              metrics:nil
                                                                                views:NSDictionaryOfVariableBindings(button)];
            
            [self addConstraints:edgeConstraint];
            [edgeConstraints addObjectsFromArray:edgeConstraint];
            [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[button]|"
                                                                         options:0L
                                                                         metrics:nil
                                                                           views:NSDictionaryOfVariableBindings(button)]];
            
            
            SWUtilityButtonTapGestureRecognizer *utilityButtonTapGestureRecognizer = [[SWUtilityButtonTapGestureRecognizer alloc] initWithTarget:_parentCell action:_utilityButtonSelector];
            utilityButtonTapGestureRecognizer.buttonIndex = utilityButtonsCounter;
            [button addGestureRecognizer:utilityButtonTapGestureRecognizer];
            
            [animationCurves addObject:[self animationValuesForButtonAtIndex:utilityButtonsCounter]];
            
            utilityButtonsCounter++;
            precedingView = button;
            animationWidth += width;
            
            
        }
        
        self.animationCurves = [animationCurves copy];
        self.edgeConstrains = [edgeConstraints copy];
    }
    
    self.widthConstraint.constant = selfWidth;
    
    [self setNeedsLayout];
    
    return;
}

#pragma mark -

- (void)pushBackgroundColors
{
    self.buttonBackgroundColors = [[NSMutableArray alloc] init];
    
    for (UIButton *button in self.utilityButtons)
    {
        [self.buttonBackgroundColors addObject:button.backgroundColor];
    }
}

- (void)popBackgroundColors
{
    NSEnumerator *e = self.utilityButtons.objectEnumerator;
    
    for (UIColor *color in self.buttonBackgroundColors)
    {
        UIButton *button = [e nextObject];
        button.backgroundColor = color;
    }
    
    self.buttonBackgroundColors = nil;
}

#pragma mark - 

- (void)setAnimationProgress:(CGFloat)animationProgress {
    _animationProgress = animationProgress;
    NSUInteger buttonsCount = self.utilityButtons.count;
    __block CGFloat animationProgressForCurrentButton = 0.f;
    [self.edgeConstrains enumerateObjectsUsingBlock:^(NSLayoutConstraint * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.constant = [self.animationCurves[idx][(NSUInteger)(animationProgress*100)] doubleValue];
    }];
}

- (NSArray *)animationValuesForButtonAtIndex:(NSUInteger)idx {
    NSUInteger numSteps = 101;
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:numSteps];
    
    double time = 0.0;
    double timeStep = 1.0 / (double)(numSteps - 1);
    NSUInteger buttonsCount = self.utilityButtons.count;
    
    for (NSUInteger i = 0; i < numSteps; i++) {
        NSValue *value = valueFxn(timeFxn(time), @(-self.buttonWidth), @((self.buttonWidth * (buttonsCount-idx-1) + 10.f)));
        [values addObject:value];
        time = MIN(1.f, MAX(0, time + timeStep));
    }
    
    return values;
}

@end

