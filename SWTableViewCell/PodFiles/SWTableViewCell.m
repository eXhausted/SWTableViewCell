//
//  SWTableViewCell.m
//  SWTableViewCell
//
//  Created by Chris Wendel on 9/10/13.
//  Copyright (c) 2013 Chris Wendel. All rights reserved.
//

#import "SWTableViewCell.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "SWUtilityButtonView.h"

#define kSectionIndexWidth 15
#define kLongPressMinimumDuration 0.16f

@interface SWTableViewCell () <UIGestureRecognizerDelegate>

@property (nonatomic, weak) UITableView *containingTableView;

@property (nonatomic, assign, readwrite) SWCellState cellState; // The state of the cell within the scroll view, can be left, right or middle
@property (nonatomic, assign) CGFloat additionalRightPadding;

@property (nonatomic, strong) UIScrollView *cellScrollView;
@property (nonatomic, strong) SWUtilityButtonView *leftUtilityButtonsView, *rightUtilityButtonsView;
@property (nonatomic, strong) UIView *leftUtilityClipView, *rightUtilityClipView;

@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

- (CGFloat)leftUtilityButtonsWidth;
- (CGFloat)rightUtilityButtonsWidth;
- (CGFloat)utilityButtonsPadding;

- (CGPoint)contentOffsetForCellState:(SWCellState)state;
- (void)updateCellState;

- (BOOL)shouldHighlight;

@end

@implementation SWTableViewCell

#pragma mark Initializers

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        [self initializer];
    }
    
    return self;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self)
    {
        [self initializer];
    }
    
    return self;
}

- (void)initializer
{
    // Set up scroll view that will host our cell content
    self.cellScrollView = [[SWCellScrollView alloc] init];
    self.cellScrollView.delegate = self;
    self.cellScrollView.showsHorizontalScrollIndicator = NO;
    self.cellScrollView.scrollsToTop = NO;
    self.cellScrollView.scrollEnabled = YES;
    self.cellScrollView.isAccessibilityElement = NO;
    [self.cellScrollView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [self addSubview:self.cellScrollView]; // in fact inserts into first subview, which is a private UITableViewCellScrollView.
    
    [self.cellScrollView setFrame:self.bounds];
    
    // Move the UITableViewCell de facto contentView into our scroll view.
    [self.cellScrollView addSubview:self.contentView];
    
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewTapped:)];
    self.tapGestureRecognizer.cancelsTouchesInView = NO;
    self.tapGestureRecognizer.delegate             = self;
    [self.cellScrollView addGestureRecognizer:self.tapGestureRecognizer];
    
    self.longPressGestureRecognizer = [[SWLongPressGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewPressed:)];
    self.longPressGestureRecognizer.cancelsTouchesInView = NO;
    self.longPressGestureRecognizer.minimumPressDuration = kLongPressMinimumDuration;
    self.longPressGestureRecognizer.delegate = self;
    [self.cellScrollView addGestureRecognizer:self.longPressGestureRecognizer];
    
    // Create the left and right utility button views, as well as vanilla UIViews in which to embed them.  We can manipulate the latter in order to effect clipping according to scroll position.
    // Such an approach is necessary in order for the utility views to sit on top to get taps, as well as allow the backgroundColor (and private UITableViewCellBackgroundView) to work properly.
    
    self.leftUtilityClipView = [[UIView alloc] init];
    self.leftUtilityClipView.isAccessibilityElement = NO;
    self.leftUtilityClipView.clipsToBounds = YES;
   // [self.leftUtilityClipView setFrame:CGRectMake(0, 0, self.frame.size.width/2, self.frame.size.height)];
    
    self.leftUtilityButtonsView.isAccessibilityElement = NO;
    self.leftUtilityButtonsView = [[SWUtilityButtonView alloc] initWithUtilityButtons:nil
                                                                           parentCell:self
                                                                utilityButtonSelector:@selector(leftUtilityButtonHandler:)];
    
    self.rightUtilityClipView = [[UIView alloc] init];
    self.rightUtilityClipView.isAccessibilityElement = NO;
    self.rightUtilityClipView.clipsToBounds = YES;
  //  [self.rightUtilityClipView setFrame:CGRectMake(self.frame.size.width/2, 0, self.frame.size.width/2, self.frame.size.height)];
    
    self.rightUtilityButtonsView.isAccessibilityElement = NO;
    self.rightUtilityButtonsView = [[SWUtilityButtonView alloc] initWithUtilityButtons:nil
                                                                            parentCell:self
                                                                 utilityButtonSelector:@selector(rightUtilityButtonHandler:)];
    
}

- (void)setContainingTableView:(UITableView *)containingTableView
{
    _containingTableView = containingTableView;
    
    if (containingTableView)
    {
        // Check if the UITableView will display Indices on the right. If that's the case, add a padding
        if ([_containingTableView.dataSource respondsToSelector:@selector(sectionIndexTitlesForTableView:)])
        {
            NSArray *indices = [_containingTableView.dataSource sectionIndexTitlesForTableView:_containingTableView];
            self.additionalRightPadding = indices == nil ? 0 : kSectionIndexWidth;
        }
        
        _containingTableView.directionalLockEnabled = YES;
        
        [self.tapGestureRecognizer requireGestureRecognizerToFail:_containingTableView.panGestureRecognizer];
    }
}

- (void)setLeftUtilityButtons:(NSArray *)leftUtilityButtons
{
    _leftUtilityButtons = leftUtilityButtons;
    
    self.leftUtilityButtonsView.utilityButtons = leftUtilityButtons;
    [self.leftUtilityButtonsView setAutoresizingMask:UIViewAutoresizingFlexibleRightMargin];
    
    [self layoutIfNeeded];
}

- (void)setRightUtilityButtons:(NSArray *)rightUtilityButtons
{
    [self.rightUtilityButtonsView removeFromSuperview];
    
    _rightUtilityButtons = rightUtilityButtons;
    
    int buttonCount = [rightUtilityButtons count];
    int width = buttonCount * kUtilityButtonWidthDefault;
    
    CGRect frame = self.rightUtilityClipView.frame;
    frame.size.width = width;
    frame.size.height = self.frame.size.height;
    frame.origin.y = 0;
    frame.origin.x = self.frame.size.width - frame.size.width;
    self.rightUtilityClipView.frame = frame;
    
    self.rightUtilityButtonsView.frame = self.rightUtilityClipView.bounds;
    [self.rightUtilityClipView addSubview:self.rightUtilityButtonsView];
    [self addSubview:self.rightUtilityClipView];
    
    self.rightUtilityButtonsView.utilityButtons = rightUtilityButtons;
    
   // [self.rightUtilityButtonsView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
    [self layoutIfNeeded];
}

#pragma mark - UITableViewCell overrides

- (void)didMoveToSuperview
{
    self.containingTableView = nil;
    UIView *view = self.superview;
    
    do {
        if ([view isKindOfClass:[UITableView class]])
        {
            self.containingTableView = (UITableView *)view;
            break;
        }
    } while ((view = view.superview));
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Offset the contentView origin so that it appears correctly w/rt the enclosing scroll view (to which we moved it).
    CGRect frame = self.contentView.frame;
    frame.origin.x = self.leftUtilityButtonsView.frame.size.width;
    self.contentView.frame = frame;
    
    self.cellScrollView.contentSize = CGSizeMake(self.frame.size.width + [self utilityButtonsPadding], self.frame.size.height);
    
    if (!self.cellScrollView.isTracking && !self.cellScrollView.isDecelerating)
    {
        self.cellScrollView.contentOffset = [self contentOffsetForCellState:_cellState];
    }

    [self updateCellState];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    _cellState = kCellStateCenter;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    // Work around stupid background-destroying override magic that UITableView seems to perform on contained buttons.
    
    [self.leftUtilityButtonsView pushBackgroundColors];
    [self.rightUtilityButtonsView pushBackgroundColors];
    
    [super setSelected:selected animated:animated];
    
    [self.leftUtilityButtonsView popBackgroundColors];
    [self.rightUtilityButtonsView popBackgroundColors];
}

#pragma mark - Selection handling

- (BOOL)shouldHighlight
{
    BOOL shouldHighlight = YES;
    
    if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:shouldHighlightRowAtIndexPath:)])
    {
        NSIndexPath *cellIndexPath = [self.containingTableView indexPathForCell:self];

        shouldHighlight = [self.containingTableView.delegate tableView:self.containingTableView shouldHighlightRowAtIndexPath:cellIndexPath];
    }

    return shouldHighlight;
}

- (void)scrollViewPressed:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan && !self.isHighlighted && self.shouldHighlight)
    {
        [self setHighlighted:YES animated:NO];
    }

    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
    {
        // Cell is already highlighted; clearing it temporarily seems to address visual anomaly.
        [self setHighlighted:NO animated:NO];
        [self scrollViewTapped:gestureRecognizer];
    }

    else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled)
    {
        [self setHighlighted:NO animated:NO];
    }
}

- (void)scrollViewTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if (_cellState == kCellStateCenter)
    {
        if (self.isSelected)
        {
            [self deselectCell];
        }
        else if (self.shouldHighlight) // UITableView refuses selection if highlight is also refused.
        {
            [self selectCell];
        }
    }
    else
    {
        // Scroll back to center
        [self hideUtilityButtonsAnimated:YES];
    }
}

- (void)selectCell
{
    if (_cellState == kCellStateCenter)
    {
        NSIndexPath *cellIndexPath = [self.containingTableView indexPathForCell:self];
        
        if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:willSelectRowAtIndexPath:)])
        {
            cellIndexPath = [self.containingTableView.delegate tableView:self.containingTableView willSelectRowAtIndexPath:cellIndexPath];
        }
        
        if (cellIndexPath)
        {
            [self.containingTableView selectRowAtIndexPath:cellIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            
            if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
            {
                [self.containingTableView.delegate tableView:self.containingTableView didSelectRowAtIndexPath:cellIndexPath];
            }
        }
    }
}

- (void)deselectCell
{
    if (_cellState == kCellStateCenter)
    {
        NSIndexPath *cellIndexPath = [self.containingTableView indexPathForCell:self];
        
        if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:willDeselectRowAtIndexPath:)])
        {
            cellIndexPath = [self.containingTableView.delegate tableView:self.containingTableView willDeselectRowAtIndexPath:cellIndexPath];
        }
        
        if (cellIndexPath)
        {
            [self.containingTableView deselectRowAtIndexPath:cellIndexPath animated:NO];
            
            if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:didDeselectRowAtIndexPath:)])
            {
                [self.containingTableView.delegate tableView:self.containingTableView didDeselectRowAtIndexPath:cellIndexPath];
            }
        }
    }
}

#pragma mark - Utility buttons handling

- (void)rightUtilityButtonHandler:(id)sender
{
    SWUtilityButtonTapGestureRecognizer *utilityButtonTapGestureRecognizer = (SWUtilityButtonTapGestureRecognizer *)sender;
    NSUInteger utilityButtonIndex = utilityButtonTapGestureRecognizer.buttonIndex;
    if ([self.delegate respondsToSelector:@selector(swipeableTableViewCell:didTriggerRightUtilityButtonWithIndex:)])
    {
        [self.delegate swipeableTableViewCell:self didTriggerRightUtilityButtonWithIndex:utilityButtonIndex];
    }
}

- (void)leftUtilityButtonHandler:(id)sender
{
    SWUtilityButtonTapGestureRecognizer *utilityButtonTapGestureRecognizer = (SWUtilityButtonTapGestureRecognizer *)sender;
    NSUInteger utilityButtonIndex = utilityButtonTapGestureRecognizer.buttonIndex;
    if ([self.delegate respondsToSelector:@selector(swipeableTableViewCell:didTriggerLeftUtilityButtonWithIndex:)])
    {
        [self.delegate swipeableTableViewCell:self didTriggerLeftUtilityButtonWithIndex:utilityButtonIndex];
    }
}

- (void)hideUtilityButtonsAnimated:(BOOL)animated
{
    if (_cellState != kCellStateCenter)
    {
        //TODO: Check again after SDK update. Temporary solution.
        if (animated) {
            [UIView animateWithDuration:0.2 animations:^{
                [self.cellScrollView setContentOffset:[self contentOffsetForCellState:kCellStateCenter]];
            }];
        } else {
            [self.cellScrollView setContentOffset:[self contentOffsetForCellState:kCellStateCenter]];
        }

        if ([self.delegate respondsToSelector:@selector(swipeableTableViewCell:scrollingToState:)])
        {
            [self.delegate swipeableTableViewCell:self scrollingToState:kCellStateCenter];
        }
    }
}


#pragma mark - Geometry helpers

- (CGFloat)leftUtilityButtonsWidth
{
    return self.leftUtilityButtonsView.frame.size.width;
}

- (CGFloat)rightUtilityButtonsWidth
{
    return self.rightUtilityButtonsView.frame.size.width + self.additionalRightPadding;
}

- (CGFloat)utilityButtonsPadding
{
    return [self leftUtilityButtonsWidth] + [self rightUtilityButtonsWidth];
}

- (CGPoint)contentOffsetForCellState:(SWCellState)state
{
    CGPoint scrollPt = CGPointZero;
    
    switch (state)
    {
        case kCellStateCenter:
            scrollPt.x = [self leftUtilityButtonsWidth];
            break;
            
        case kCellStateLeft:
            scrollPt.x = 0;
            break;
            
        case kCellStateRight:
            scrollPt.x = [self utilityButtonsPadding];
            break;
    }
    
    return scrollPt;
}

- (void)updateCellState
{
    // Update the cell state according to the current scroll view contentOffset.
    for (NSNumber *numState in @[
                                 @(kCellStateCenter),
                                 @(kCellStateLeft),
                                 @(kCellStateRight),
                                 ])
    {
        SWCellState cellState = numState.integerValue;
        
        if (CGPointEqualToPoint(self.cellScrollView.contentOffset, [self contentOffsetForCellState:cellState]))
        {
            _cellState = cellState;
            break;
        }
    }

    // Update the clipping on the utility button views according to the current position.
    CGRect frame = [self.contentView.superview convertRect:self.contentView.frame toView:self];
    
    CGRect leftFrame = self.leftUtilityClipView.frame;
    leftFrame.size.width = MAX(0, CGRectGetMinX(frame) - CGRectGetMinX(self.frame));
    self.leftUtilityClipView.frame = leftFrame;
    
    CGRect rightFrame = self.rightUtilityClipView.frame;
    rightFrame.size.width = MIN(0, CGRectGetMaxX(frame) - CGRectGetMaxX(self.frame));
    rightFrame.origin.x = self.frame.size.width - leftFrame.size.width;
    self.rightUtilityClipView.frame = rightFrame;
    
    CGRect rightButtonsFrame = self.rightUtilityButtonsView.frame;
    rightButtonsFrame.origin.x = self.rightUtilityClipView.frame.size.width - rightButtonsFrame.size.width;
    self.rightUtilityButtonsView.frame = rightButtonsFrame;
    
    // Enable or disable the gesture recognizers according to the current mode.
    if (!self.cellScrollView.isDragging && !self.cellScrollView.isDecelerating)
    {
        self.tapGestureRecognizer.enabled = YES;
        self.longPressGestureRecognizer.enabled = (_cellState == kCellStateCenter);
    }
    else
    {
        self.tapGestureRecognizer.enabled = NO;
        self.longPressGestureRecognizer.enabled = NO;
    }

    self.cellScrollView.scrollEnabled = !self.isEditing;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (velocity.x >= 0.5f)
    {
        if (_cellState == kCellStateLeft)
        {
            _cellState = kCellStateCenter;
        }
        else
        {
            _cellState = kCellStateRight;
        }
    }
    else if (velocity.x <= -0.5f)
    {
        if (_cellState == kCellStateRight)
        {
            _cellState = kCellStateCenter;
        }
        else
        {
            _cellState = kCellStateLeft;
        }
    }
    else
    {
        CGFloat leftThreshold = [self contentOffsetForCellState:kCellStateLeft].x + (self.leftUtilityButtonsWidth / 2);
        CGFloat rightThreshold = [self contentOffsetForCellState:kCellStateRight].x - (self.rightUtilityButtonsWidth / 2);
        
        if (targetContentOffset->x > rightThreshold)
        {
            _cellState = kCellStateRight;
        }
        else if (targetContentOffset->x < leftThreshold)
        {
            _cellState = kCellStateLeft;
        }
        else
        {
            _cellState = kCellStateCenter;
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(swipeableTableViewCell:scrollingToState:)])
    {
        [self.delegate swipeableTableViewCell:self scrollingToState:_cellState];
    }
    
    if (_cellState != kCellStateCenter)
    {
        if ([self.delegate respondsToSelector:@selector(swipeableTableViewCellShouldHideUtilityButtonsOnSwipe:)])
        {
            for (SWTableViewCell *cell in [self.containingTableView visibleCells]) {
                if (cell != self && [cell isKindOfClass:[SWTableViewCell class]] && [self.delegate swipeableTableViewCellShouldHideUtilityButtonsOnSwipe:cell]) {
                    [cell hideUtilityButtonsAnimated:YES];
                }
            }
        }
    }
    
    *targetContentOffset = [self contentOffsetForCellState:_cellState];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.x > [self leftUtilityButtonsWidth])
    {
        if ([self rightUtilityButtonsWidth] > 0)
        {
            if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableTableViewCell:canSwipeToState:)])
            {
                BOOL shouldScroll = [self.delegate swipeableTableViewCell:self canSwipeToState:kCellStateRight];
                if (!shouldScroll)
                {
                    scrollView.contentOffset = CGPointMake([self leftUtilityButtonsWidth], 0);
                }
            }
        }
        else
        {
            [scrollView setContentOffset:CGPointMake([self leftUtilityButtonsWidth], 0)];
            self.tapGestureRecognizer.enabled = YES;
        }
    }
    else
    {
        // Expose the left button view
        if ([self leftUtilityButtonsWidth] > 0)
        {
            if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableTableViewCell:canSwipeToState:)])
            {
                BOOL shouldScroll = [self.delegate swipeableTableViewCell:self canSwipeToState:kCellStateLeft];
                if (!shouldScroll)
                {
                    scrollView.contentOffset = CGPointMake([self leftUtilityButtonsWidth], 0);
                }
            }
        }
        else
        {
            [scrollView setContentOffset:CGPointMake(0, 0)];
            self.tapGestureRecognizer.enabled = YES;
        }
    }
    
    [self updateCellState];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self updateCellState];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self updateCellState];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ((gestureRecognizer == self.containingTableView.panGestureRecognizer && otherGestureRecognizer == self.longPressGestureRecognizer)
        || (gestureRecognizer == self.longPressGestureRecognizer && otherGestureRecognizer == self.containingTableView.panGestureRecognizer))
    {
        // Return YES so the pan gesture of the containing table view is not cancelled by the long press recognizer
        return YES;
    }
    else
    {
        return NO;
    }
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ![touch.view isKindOfClass:[UIControl class]];
}

@end
