#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, JoiCubismMood) {
    JoiCubismMoodNeutral = 0,
    JoiCubismMoodAttentive = 1,
    JoiCubismMoodThinking = 2,
    JoiCubismMoodDelighted = 3,
    JoiCubismMoodConcerned = 4,
};

/// Native Live2D surface used by Joi Map. The view owns its Metal render loop,
/// while SwiftUI only updates high-level character state.
@interface JoiCubismView : UIView

@property(nonatomic) JoiCubismMood mood;
@property(nonatomic, getter=isSpeaking) BOOL speaking;
@property(nonatomic) CGFloat lookX;
@property(nonatomic) CGFloat lookY;
@property(nonatomic) CGFloat zoom;
@property(nonatomic) CGFloat verticalOffset;
@property(nonatomic, readonly, getter=isModelLoaded) BOOL modelLoaded;

- (instancetype)initWithFrame:(CGRect)frame
                    modelPath:(NSString *)modelPath
                  texturePath:(NSString *)texturePath NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
