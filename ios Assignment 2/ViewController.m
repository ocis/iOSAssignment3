//
//  ViewController.m
//  ios Assignment 2
//
//  Created by Billy Wong on 2020-03-12.
//  Copyright © 2020 BCIT. All rights reserved.
//

#import "ViewController.h"

@interface ViewController (){
    Renderer *renderer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    renderer = [[Renderer alloc] init];
    GLKView *view = (GLKView *)self.view;
    [renderer setup:view];
    [renderer loadModels];
    [renderer loadWallModel];
    [renderer loadMarkerModel];
    [renderer loadEnemyModel];
    
    [renderer initMaze];
    
    renderer.xRot = 30 * M_PI / 180;
    renderer.yRot = 30 * M_PI / 180;
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipeToMove:)];
    panRecognizer.maximumNumberOfTouches = 1;
    //[upRecognizer setDirection:uipangester];
    [self.view addGestureRecognizer:panRecognizer];
    
    UITapGestureRecognizer *resetRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapToReset:)];
    resetRecognizer.numberOfTouchesRequired = 1;
    resetRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:resetRecognizer];
    
    UITapGestureRecognizer *mapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapForMap:)];
    mapRecognizer.numberOfTouchesRequired = 2;
    mapRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:mapRecognizer];


}


- (void)update{
    [renderer update];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [renderer draw:rect];
}

- (void)swipeToMove:(UIPanGestureRecognizer *)sender
{
    CGPoint velocity = [sender velocityInView:self.view];
    
    if(fabs(velocity.y) > fabs(velocity.x)){
        if(velocity.y > 100){
            renderer->viewTranslateZ -= 0.1 * cosf(renderer->viewRotateY);
            renderer->viewTranslateX -= 0.1 * sinf(renderer->viewRotateY);
        }
        if(velocity.y < -100){
            renderer->viewTranslateZ += 0.1 * cosf(renderer->viewRotateY);
            renderer->viewTranslateX += 0.1 * sinf(renderer->viewRotateY);
        }
    } else{
        if(velocity.x > 100){
            renderer->viewRotateY -= 0.02;
        }
        if(velocity.x < -100){
            renderer->viewRotateY += 0.02;
        }
    }
}

- (void)doubleTapToReset:(UITapGestureRecognizer *)sender
{
    renderer->viewTranslateZ = 0.0f;
    renderer->viewTranslateX = 0.0f;
    renderer->viewRotateY = 0.0f;
}

- (void)doubleTapForMap:(UITapGestureRecognizer *)sender
{
    renderer->enableMap = !renderer->enableMap;
}

@end
