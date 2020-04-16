//
//  Copyright © Borna Noureddin. All rights reserved.
//

#ifndef Renderer_h
#define Renderer_h
#import <GLKit/GLKit.h>


@interface Renderer : NSObject
{
    @public float viewTranslateX, viewTranslateY, viewTranslateZ;
    @public float viewRotateX, viewRotateY, viewRotateZ;
    @public float minimapViewRotateX, minimapViewRotateY, minimapViewRotateZ;
    @public float minimapTranslateX, minimapTranslateY, minimapTranslateZ;
    @public bool enableMap;
}

// Properties to interface with iOS UI code
@property float rotAngle, xRot, yRot;
@property bool isRotating;

- (void)setup:(GLKView *)view;      // Set up GL using the current View
- (void)loadModels;// Load models (e.g., cube to rotate)
- (void)loadEnemyModel; // Loads enemy model from obj file
- (void)loadWallModel; // Loads wall
- (void)loadMarkerModel; //Loads marker
- (void)initMaze;
- (void)update;                     // Update GL
- (void)draw:(CGRect)drawRect;      // Make the GL draw calls
- (void)setUniforms:(GLKMatrix4)_modelViewProjectionMatrix :(GLKMatrix3)_normalMatrix :(GLKMatrix4)_modelViewMatrix;

@end

#endif /* Renderer_h */
