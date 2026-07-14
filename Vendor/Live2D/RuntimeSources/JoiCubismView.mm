#import "JoiCubismView.h"

#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>

#include <algorithm>
#include <cmath>
#include <limits>

#include <CubismFramework.hpp>
#include <ICubismAllocator.hpp>
#include <Id/CubismIdManager.hpp>
#include <Math/CubismMatrix44.hpp>
#include <Model/CubismUserModel.hpp>
#include <Rendering/Metal/CubismDeviceInfo_Metal.hpp>
#include <Rendering/Metal/CubismRenderer_Metal.hpp>

using namespace Live2D::Cubism::Framework;
using namespace Live2D::Cubism::Framework::Rendering;

namespace Live2D {
namespace Cubism {
namespace Framework {
namespace Rendering {

id<MTLLibrary> JoiLoadCubismShaderLibrary(id<MTLDevice> device, NSString* sourceName) {
    static NSMutableDictionary<NSString*, id<MTLLibrary>>* libraryCache;
    static dispatch_once_t cacheToken;
    dispatch_once(&cacheToken, ^{
        libraryCache = [NSMutableDictionary dictionary];
    });

    NSString* cacheKey = [NSString stringWithFormat:@"%p-%@", device, sourceName];
    @synchronized(libraryCache) {
        id<MTLLibrary> cachedLibrary = libraryCache[cacheKey];
        if (cachedLibrary) {
            return cachedLibrary;
        }
    }

    NSError* readError = nil;
    NSString* shaderDirectory = [[NSBundle mainBundle] pathForResource:@"Live2DShaders" ofType:nil];
    if (!shaderDirectory) {
        NSLog(@"Joi Live2D shader directory is unavailable");
        return nil;
    }
    NSString* shaderPath = [shaderDirectory stringByAppendingPathComponent:
        [sourceName stringByAppendingPathExtension:@"metal"]];
    NSString* typesPath = [shaderDirectory stringByAppendingPathComponent:@"MetalShaderTypes.h"];
    NSString* structsPath = [shaderDirectory stringByAppendingPathComponent:@"BlendShaderStructs.h"];
    NSString* funcsPath = [shaderDirectory stringByAppendingPathComponent:@"BlendShaderFuncs.h"];
    NSString* alphaPath = [shaderDirectory stringByAppendingPathComponent:@"FragShaderSrcAlphaBlend.metal"];
    NSString* colorPath = [shaderDirectory stringByAppendingPathComponent:@"FragShaderSrcColorBlend.metal"];
    NSString* shaderSource = shaderPath
        ? [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&readError]
        : nil;
    NSString* typesSource = typesPath
        ? [NSString stringWithContentsOfFile:typesPath encoding:NSUTF8StringEncoding error:&readError]
        : nil;
    NSString* structsSource = [NSString stringWithContentsOfFile:structsPath encoding:NSUTF8StringEncoding error:&readError];
    NSString* funcsSource = [NSString stringWithContentsOfFile:funcsPath encoding:NSUTF8StringEncoding error:&readError];
    NSString* alphaSource = [NSString stringWithContentsOfFile:alphaPath encoding:NSUTF8StringEncoding error:&readError];
    NSString* colorSource = [NSString stringWithContentsOfFile:colorPath encoding:NSUTF8StringEncoding error:&readError];

    if (!shaderSource || !typesSource || !structsSource || !funcsSource || !alphaSource || !colorSource) {
        NSLog(@"Joi Live2D shader resource %@ is unavailable: %@", sourceName, readError.localizedDescription);
        return nil;
    }

    funcsSource = [funcsSource
        stringByReplacingOccurrencesOfString:@"#include \"FragShaderSrcAlphaBlend.metal\""
        withString:alphaSource];
    funcsSource = [funcsSource
        stringByReplacingOccurrencesOfString:@"#include \"FragShaderSrcColorBlend.metal\""
        withString:colorSource];
    shaderSource = [shaderSource
        stringByReplacingOccurrencesOfString:@"#include \"MetalShaderTypes.h\""
        withString:typesSource];
    shaderSource = [shaderSource
        stringByReplacingOccurrencesOfString:@"#include \"BlendShaderStructs.h\""
        withString:structsSource];
    shaderSource = [shaderSource
        stringByReplacingOccurrencesOfString:@"#include \"BlendShaderFuncs.h\""
        withString:funcsSource];

    NSError* compileError = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:shaderSource options:nil error:&compileError];
    if (!library) {
        NSLog(@"Joi Live2D shader %@ compilation failed: %@", sourceName, compileError.localizedDescription);
        return nil;
    }

    @synchronized(libraryCache) {
        libraryCache[cacheKey] = library;
    }
    return library;
}

} // namespace Rendering
} // namespace Framework
} // namespace Cubism
} // namespace Live2D

namespace {

class JoiCubismAllocator final : public ICubismAllocator {
public:
    void* Allocate(const csmSizeType size) override {
        return std::malloc(size);
    }

    void Deallocate(void* memory) override {
        std::free(memory);
    }

    void* AllocateAligned(const csmSizeType size, const csmUint32 alignment) override {
        const size_t offset = alignment - 1 + sizeof(void*);
        void* allocation = Allocate(size + offset);
        if (!allocation) {
            return nullptr;
        }

        size_t alignedAddress = reinterpret_cast<size_t>(allocation) + sizeof(void*);
        const size_t shift = alignedAddress % alignment;
        if (shift) {
            alignedAddress += alignment - shift;
        }

        void** preamble = reinterpret_cast<void**>(alignedAddress);
        preamble[-1] = allocation;
        return reinterpret_cast<void*>(alignedAddress);
    }

    void DeallocateAligned(void* alignedMemory) override {
        if (!alignedMemory) {
            return;
        }
        void** preamble = static_cast<void**>(alignedMemory);
        Deallocate(preamble[-1]);
    }
};

JoiCubismAllocator gAllocator;
NSInteger gRuntimeReferences = 0;
NSLock* gRuntimeLock = [[NSLock alloc] init];

void AcquireCubismRuntime() {
    [gRuntimeLock lock];
    if (gRuntimeReferences == 0) {
        CubismFramework::StartUp(&gAllocator);
        CubismFramework::Initialize();
    }
    gRuntimeReferences += 1;
    [gRuntimeLock unlock];
}

void ReleaseCubismRuntime() {
    [gRuntimeLock lock];
    gRuntimeReferences = std::max<NSInteger>(0, gRuntimeReferences - 1);
    if (gRuntimeReferences == 0) {
        CubismDeviceInfo_Metal::ReleaseAllDeviceInfo();
        CubismRenderer::StaticRelease();
        CubismFramework::Dispose();
        CubismFramework::CleanUp();
    }
    [gRuntimeLock unlock];
}

class JoiCubismModel final : public CubismUserModel {
public:
    explicit JoiCubismModel(id<MTLDevice> device)
        : _device(device),
          _texture(nil),
          _loaded(false),
          _time(0.0),
          _speaking(false),
          _mood(JoiCubismMoodNeutral),
          _lookX(0.0f),
          _lookY(0.0f),
          _zoom(1.0f),
          _verticalOffset(0.0f),
          _contentMinX(0.0f),
          _contentMaxX(0.0f),
          _contentMinY(0.0f),
          _contentMaxY(0.0f) {
        CubismIdManager* ids = CubismFramework::GetIdManager();
        _angleX = ids->GetId("ParamAngleX");
        _angleY = ids->GetId("ParamAngleY");
        _angleZ = ids->GetId("ParamAngleZ");
        _bodyAngleX = ids->GetId("ParamBodyAngleX");
        _eyeBallX = ids->GetId("ParamEyeBallX");
        _eyeBallY = ids->GetId("ParamEyeBallY");
        _eyeLOpen = ids->GetId("ParamEyeLOpen");
        _eyeROpen = ids->GetId("ParamEyeROpen");
        _eyeLSmile = ids->GetId("ParamEyeLSmile");
        _eyeRSmile = ids->GetId("ParamEyeRSmile");
        _browLY = ids->GetId("ParamBrowLY");
        _browRY = ids->GetId("ParamBrowRY");
        _browLAngle = ids->GetId("ParamBrowLAngle");
        _browRAngle = ids->GetId("ParamBrowRAngle");
        _mouthForm = ids->GetId("ParamMouthForm");
        _mouthOpen = ids->GetId("ParamMouthOpenY");
        _cheek = ids->GetId("ParamCheek");
        _breath = ids->GetId("ParamBreath");
        _hairFront = ids->GetId("ParamHairFront");
        _hairSide = ids->GetId("ParamHairSide");
        _hairBack = ids->GetId("ParamHairBack");
    }

    bool Load(NSString* modelPath, NSString* texturePath, CGSize drawableSize) {
        NSData* modelData = [NSData dataWithContentsOfFile:modelPath];
        if (!modelData || modelData.length == 0) {
            return false;
        }

        LoadModel(static_cast<const csmByte*>(modelData.bytes),
                  static_cast<csmSizeInt>(modelData.length),
                  true);
        if (!GetModel()) {
            return false;
        }

        if (GetModel()->IsBlendModeEnabled()) {
            NSLog(@"Joi Live2D model uses unsupported advanced blend modes");
            return false;
        }

        GetModel()->Update();
        if (!CalculateContentBounds()) {
            NSLog(@"Joi Live2D model has no drawable geometry");
            return false;
        }

        const csmUint32 width = std::max<csmUint32>(1, static_cast<csmUint32>(drawableSize.width));
        const csmUint32 height = std::max<csmUint32>(1, static_cast<csmUint32>(drawableSize.height));
        CreateRenderer(width, height);

        MTKTextureLoader* loader = [[MTKTextureLoader alloc] initWithDevice:_device];
        NSDictionary<MTKTextureLoaderOption, id>* options = @{
            MTKTextureLoaderOptionSRGB: @NO,
            MTKTextureLoaderOptionGenerateMipmaps: @YES,
            MTKTextureLoaderOptionTextureUsage: @(MTLTextureUsageShaderRead),
        };
        NSError* error = nil;
        _texture = [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:texturePath]
                                               options:options
                                                 error:&error];
        if (!_texture || error) {
            DeleteRenderer();
            return false;
        }

        CubismRenderer_Metal* renderer = GetRenderer<CubismRenderer_Metal>();
        renderer->BindTexture(0, _texture);
        renderer->IsPremultipliedAlpha(false);
        _loaded = true;
        return true;
    }

    bool IsLoaded() const {
        return _loaded;
    }

    void SetState(bool speaking, JoiCubismMood mood, float lookX, float lookY) {
        _speaking = speaking;
        _mood = mood;
        _lookX = std::min(1.0f, std::max(-1.0f, lookX));
        _lookY = std::min(1.0f, std::max(-1.0f, lookY));
    }

    void SetFraming(float zoom, float verticalOffset) {
        _zoom = std::min(3.5f, std::max(0.75f, zoom));
        _verticalOffset = std::min(4.0f, std::max(-4.0f, verticalOffset));
    }

    void Resize(CGSize drawableSize) {
        if (!_loaded) {
            return;
        }
        GetRenderer<CubismRenderer_Metal>()->SetRenderTargetSize(
            std::max<csmUint32>(1, static_cast<csmUint32>(drawableSize.width)),
            std::max<csmUint32>(1, static_cast<csmUint32>(drawableSize.height))
        );
    }

    void Update(double deltaTime) {
        if (!_loaded || !GetModel()) {
            return;
        }

        _time += std::min(0.1, std::max(0.0, deltaTime));

        const float sway = static_cast<float>(std::sin(_time * 0.82));
        const float breath = 0.5f + 0.5f * static_cast<float>(std::sin(_time * 1.45));
        const float blinkPhase = static_cast<float>(std::fmod(_time + 0.35, 4.3));
        float eyeOpen = 1.0f;
        if (blinkPhase < 0.16f) {
            eyeOpen = std::abs(std::cos(blinkPhase / 0.16f * static_cast<float>(M_PI)));
        }

        float mouthForm = 0.18f;
        float cheek = 0.12f;
        float eyeSmile = 0.0f;
        float browY = 0.0f;
        float browAngle = 0.0f;
        float moodAngleX = 0.0f;
        float moodAngleY = 0.0f;

        switch (_mood) {
        case JoiCubismMoodAttentive:
            mouthForm = 0.28f;
            cheek = 0.18f;
            moodAngleY = -2.0f;
            break;
        case JoiCubismMoodThinking:
            mouthForm = -0.08f;
            moodAngleX = -8.0f;
            moodAngleY = 4.0f;
            browY = 0.25f;
            break;
        case JoiCubismMoodDelighted:
            mouthForm = 0.82f;
            cheek = 0.48f;
            eyeSmile = 0.42f;
            browY = 0.18f;
            break;
        case JoiCubismMoodConcerned:
            mouthForm = -0.34f;
            moodAngleX = 6.0f;
            browY = 0.22f;
            browAngle = -0.28f;
            break;
        case JoiCubismMoodNeutral:
        default:
            break;
        }

        float mouthOpen = 0.0f;
        if (_speaking) {
            const float envelope = static_cast<float>(std::pow(std::sin(_time * 12.5), 2.0));
            mouthOpen = 0.22f + envelope * 0.72f;
            mouthForm = std::max(mouthForm, 0.38f);
        }

        CubismModel* model = GetModel();
        model->SetParameterValue(_angleX, moodAngleX + _lookX * 16.0f + sway * 1.8f);
        model->SetParameterValue(_angleY, moodAngleY + _lookY * 12.0f);
        model->SetParameterValue(_angleZ, sway * 1.6f);
        model->SetParameterValue(_bodyAngleX, sway * 1.4f + _lookX * 2.2f);
        model->SetParameterValue(_eyeBallX, _lookX * 0.62f);
        model->SetParameterValue(_eyeBallY, _lookY * 0.48f);
        model->SetParameterValue(_eyeLOpen, eyeOpen);
        model->SetParameterValue(_eyeROpen, eyeOpen);
        model->SetParameterValue(_eyeLSmile, eyeSmile);
        model->SetParameterValue(_eyeRSmile, eyeSmile);
        model->SetParameterValue(_browLY, browY);
        model->SetParameterValue(_browRY, browY);
        model->SetParameterValue(_browLAngle, browAngle);
        model->SetParameterValue(_browRAngle, -browAngle);
        model->SetParameterValue(_mouthForm, mouthForm);
        model->SetParameterValue(_mouthOpen, mouthOpen);
        model->SetParameterValue(_cheek, cheek);
        model->SetParameterValue(_breath, breath);
        model->SetParameterValue(_hairFront, sway * 0.22f);
        model->SetParameterValue(_hairSide, -sway * 0.28f);
        model->SetParameterValue(_hairBack, sway * 0.18f);
        model->Update();
    }

    void Draw(id<MTLCommandBuffer> commandBuffer,
              MTLRenderPassDescriptor* renderPassDescriptor,
              CGSize drawableSize) {
        if (!_loaded || !GetModel()) {
            return;
        }

        CubismRenderer_Metal* renderer = GetRenderer<CubismRenderer_Metal>();
        renderer->StartFrame(commandBuffer, renderPassDescriptor);
        const MTLViewport viewport = {
            0.0,
            0.0,
            static_cast<double>(drawableSize.width),
            static_cast<double>(drawableSize.height),
            0.0,
            1.0,
        };
        renderer->SetRenderViewport(viewport);

        CubismMatrix44 projection;
        const float width = std::max(1.0f, static_cast<float>(drawableSize.width));
        const float height = std::max(1.0f, static_cast<float>(drawableSize.height));
        const float aspect = width / height;

        const float contentWidth = std::max(0.001f, _contentMaxX - _contentMinX);
        const float contentHeight = std::max(0.001f, _contentMaxY - _contentMinY);
        const float contentCenterX = (_contentMinX + _contentMaxX) * 0.5f;
        const float contentCenterY = (_contentMinY + _contentMaxY) * 0.5f;
        const float fitScale = 1.82f / std::max(contentHeight, contentWidth / aspect);

        CubismMatrix44 contentMatrix;
        contentMatrix.Scale(fitScale * _zoom, fitScale * _zoom);
        contentMatrix.Translate(
            -contentCenterX * fitScale * _zoom,
            -contentCenterY * fitScale * _zoom + _verticalOffset
        );
        projection.Scale(1.0f / aspect, 1.0f);
        projection.MultiplyByMatrix(&contentMatrix);
        renderer->SetMvpMatrix(&projection);
        renderer->DrawModel();
    }

private:
    bool CalculateContentBounds() {
        CubismModel* model = GetModel();
        if (!model) {
            return false;
        }

        float minX = std::numeric_limits<float>::max();
        float maxX = std::numeric_limits<float>::lowest();
        float minY = std::numeric_limits<float>::max();
        float maxY = std::numeric_limits<float>::lowest();
        bool foundVertex = false;

        for (csmInt32 drawableIndex = 0; drawableIndex < model->GetDrawableCount(); ++drawableIndex) {
            const csmInt32 vertexCount = model->GetDrawableVertexCount(drawableIndex);
            const auto* positions = model->GetDrawableVertexPositions(drawableIndex);
            for (csmInt32 vertexIndex = 0; vertexIndex < vertexCount; ++vertexIndex) {
                minX = std::min(minX, positions[vertexIndex].X);
                maxX = std::max(maxX, positions[vertexIndex].X);
                minY = std::min(minY, positions[vertexIndex].Y);
                maxY = std::max(maxY, positions[vertexIndex].Y);
                foundVertex = true;
            }
        }

        if (!foundVertex || maxX <= minX || maxY <= minY) {
            return false;
        }

        _contentMinX = minX;
        _contentMaxX = maxX;
        _contentMinY = minY;
        _contentMaxY = maxY;
        return true;
    }

    __strong id<MTLDevice> _device;
    __strong id<MTLTexture> _texture;
    bool _loaded;
    double _time;
    bool _speaking;
    JoiCubismMood _mood;
    float _lookX;
    float _lookY;
    float _zoom;
    float _verticalOffset;
    float _contentMinX;
    float _contentMaxX;
    float _contentMinY;
    float _contentMaxY;

    CubismIdHandle _angleX;
    CubismIdHandle _angleY;
    CubismIdHandle _angleZ;
    CubismIdHandle _bodyAngleX;
    CubismIdHandle _eyeBallX;
    CubismIdHandle _eyeBallY;
    CubismIdHandle _eyeLOpen;
    CubismIdHandle _eyeROpen;
    CubismIdHandle _eyeLSmile;
    CubismIdHandle _eyeRSmile;
    CubismIdHandle _browLY;
    CubismIdHandle _browRY;
    CubismIdHandle _browLAngle;
    CubismIdHandle _browRAngle;
    CubismIdHandle _mouthForm;
    CubismIdHandle _mouthOpen;
    CubismIdHandle _cheek;
    CubismIdHandle _breath;
    CubismIdHandle _hairFront;
    CubismIdHandle _hairSide;
    CubismIdHandle _hairBack;
};

} // namespace

@interface JoiCubismView () <MTKViewDelegate>
@property(nonatomic, strong) MTKView* metalView;
@property(nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic) JoiCubismModel* model;
@property(nonatomic) CFTimeInterval previousFrameTime;
@property(nonatomic, readwrite, getter=isModelLoaded) BOOL modelLoaded;
@end

@implementation JoiCubismView

- (instancetype)initWithFrame:(CGRect)frame
                    modelPath:(NSString*)modelPath
                  texturePath:(NSString*)texturePath {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    AcquireCubismRuntime();
    _mood = JoiCubismMoodNeutral;
    _speaking = NO;
    _lookX = 0.0;
    _lookY = 0.0;
    _zoom = 1.0;
    _verticalOffset = 0.0;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.clipsToBounds = YES;

    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        return self;
    }

    CubismRenderer_Metal::SetConstantSettings(_device);
    _commandQueue = [_device newCommandQueue];
    _metalView = [[MTKView alloc] initWithFrame:self.bounds device:_device];
    _metalView.translatesAutoresizingMaskIntoConstraints = NO;
    _metalView.delegate = self;
    _metalView.opaque = NO;
    _metalView.backgroundColor = UIColor.clearColor;
    _metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    _metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    _metalView.framebufferOnly = NO;
    _metalView.preferredFramesPerSecond = 30;
    _metalView.enableSetNeedsDisplay = NO;
    _metalView.paused = NO;
    [self addSubview:_metalView];
    [NSLayoutConstraint activateConstraints:@[
        [_metalView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_metalView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_metalView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_metalView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    const CGFloat scale = UIScreen.mainScreen.scale;
    const CGSize initialSize = CGSizeMake(
        MAX(1.0, frame.size.width * scale),
        MAX(1.0, frame.size.height * scale)
    );
    _model = new JoiCubismModel(_device);
    _modelLoaded = _model->Load(modelPath, texturePath, initialSize);
    _previousFrameTime = CACurrentMediaTime();
    return self;
}

- (void)dealloc {
    _metalView.delegate = nil;
    _metalView.paused = YES;
    if (_model) {
        delete _model;
        _model = nullptr;
    }
    ReleaseCubismRuntime();
}

- (void)setSpeaking:(BOOL)speaking {
    _speaking = speaking;
    _metalView.preferredFramesPerSecond = speaking ? 60 : 30;
}

- (void)setLookX:(CGFloat)lookX {
    _lookX = MIN(1.0, MAX(-1.0, lookX));
}

- (void)setLookY:(CGFloat)lookY {
    _lookY = MIN(1.0, MAX(-1.0, lookY));
}

- (void)setZoom:(CGFloat)zoom {
    _zoom = MIN(3.5, MAX(0.75, zoom));
}

- (void)setVerticalOffset:(CGFloat)verticalOffset {
    _verticalOffset = MIN(4.0, MAX(-4.0, verticalOffset));
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
    if (_model) {
        _model->Resize(size);
    }
}

- (void)drawInMTKView:(MTKView*)view {
    if (!_model || !_modelLoaded || !_commandQueue) {
        return;
    }

    @autoreleasepool {
        MTLRenderPassDescriptor* descriptor = view.currentRenderPassDescriptor;
        id<CAMetalDrawable> drawable = view.currentDrawable;
        if (!descriptor || !drawable) {
            return;
        }

        const CFTimeInterval now = CACurrentMediaTime();
        const double delta = _previousFrameTime > 0 ? now - _previousFrameTime : 1.0 / 30.0;
        _previousFrameTime = now;
        _model->SetState(_speaking, _mood, static_cast<float>(_lookX), static_cast<float>(_lookY));
        _model->SetFraming(static_cast<float>(_zoom), static_cast<float>(_verticalOffset));
        _model->Update(delta);

        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        CubismDeviceInfo_Metal* deviceInfo = CubismDeviceInfo_Metal::GetDeviceInfo(_device);
        deviceInfo->GetOffscreenManager()->BeginFrameProcess();
        _model->Draw(commandBuffer, descriptor, view.drawableSize);
        deviceInfo->GetOffscreenManager()->EndFrameProcess();
        deviceInfo->GetOffscreenManager()->ReleaseStaleRenderTextures();

        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

@end
