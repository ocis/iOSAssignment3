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
    int axis;
}
@end

@implementation ViewController
UIPinchGestureRecognizer *scaleRecognizer;

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
    axis = 0;
    
    [renderer initMaze];
    
    renderer.xRot = 30 * M_PI / 180;
    renderer.yRot = 30 * M_PI / 180;
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipeToMove:)];
    panRecognizer.minimumNumberOfTouches = 1;
    panRecognizer.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:panRecognizer];
    
    UIPanGestureRecognizer *panEnemyRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipeToMoveEnemy:)];
    panEnemyRecognizer.minimumNumberOfTouches = 2;
    panEnemyRecognizer.maximumNumberOfTouches = 2;
    [self.view addGestureRecognizer:panEnemyRecognizer];
    
    UITapGestureRecognizer *resetRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapToReset:)];
    resetRecognizer.numberOfTouchesRequired = 1;
    resetRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:resetRecognizer];
    
    UITapGestureRecognizer *mapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapForMap:)];
    mapRecognizer.numberOfTouchesRequired = 2;
    mapRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:mapRecognizer];

    UITapGestureRecognizer *editRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapForEdit:)];
    editRecognizer.numberOfTouchesRequired = 3;
    editRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:editRecognizer];
    
    scaleRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchForEnemyScale:)];
    [self.view addGestureRecognizer:scaleRecognizer];
    scaleRecognizer.enabled = false;
    
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeUpToMovePositive:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    swipeUp.numberOfTouchesRequired = 3;
    [self.view addGestureRecognizer:swipeUp];
    
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeDownToMoveNegative:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    swipeDown.numberOfTouchesRequired = 3;
    [self.view addGestureRecognizer:swipeDown];

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
    if(renderer->enableEnemyEdit){
        if(velocity.y > 50){
            renderer->enemyScreenRotateX += 0.1f;
            if(renderer->enemyScreenRotateX > 360.0f){
                renderer->enemyScreenRotateX = renderer->enemyScreenRotateX - M_2_PI;
            }
        } else if(velocity.y < -50){
            renderer->enemyScreenRotateX -= 0.1f;
            if(renderer->enemyScreenRotateX < -360.0f){
                renderer->enemyScreenRotateX = renderer->enemyScreenRotateX + M_2_PI;
            }
        }
        renderer->enemyScreenRotateXFactor = cosf(renderer->viewRotateY);
        renderer->enemyScreenRotateZFactor = -sinf(renderer->viewRotateY);
        
        if(velocity.x > 50){
            renderer->enemyScreenRotateY += 0.1f;
            if(renderer->enemyScreenRotateY > 360.0f){
                renderer->enemyScreenRotateY = renderer->enemyScreenRotateY - M_2_PI;
            }
        } else if(velocity.x < 50){
            renderer->enemyScreenRotateY -= 0.1f;
            if(renderer->enemyScreenRotateY < -360.0f){
                renderer->enemyScreenRotateY = renderer->enemyScreenRotateY + M_2_PI;
            }
        }

    } else{
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
}

- (void)doubleTapToReset:(UITapGestureRecognizer *)sender
{
    if(renderer->enableEnemyEdit){
        axis += 1;
        if(axis > 2){
            axis = 0;
        }
    } else{
        renderer->viewTranslateZ = 0.0f;
        renderer->viewTranslateX = 0.0f;
        renderer->viewRotateY = 0.0f;
    }
}

- (void)doubleTapForMap:(UITapGestureRecognizer *)sender
{
    if(scaleRecognizer.enabled == false){
        renderer->enableMap = !renderer->enableMap;
    } else{
        scaleRecognizer.enabled = false;
        renderer->enableEnemyEdit = false;
        [renderer resetEdits];
        NSLog(@"disabling edit mode");
    }

}

- (void)doubleTapForEdit:(UITapGestureRecognizer *)sender
{
    GLKVector3 enemyPos = GLKVector3Make(renderer->enemyMoveX, 0.0f, renderer->enemyMoveZ + 2);
    GLKVector3 cameraPos = GLKVector3Make(renderer->viewTranslateX, 0.0f, renderer->viewTranslateZ);
    float distanceFromEnemy = GLKVector3Distance(enemyPos, cameraPos);

    NSLog(@"distance from enemy: %f", distanceFromEnemy);
    if(distanceFromEnemy <= 1.0f){
        renderer->enableEnemyEdit = true;
        scaleRecognizer.enabled = true;
        NSLog(@"Edit mode switch");
    }
}

- (void)pinchForEnemyScale:(UIPinchGestureRecognizer *)sender{
    if(renderer->enableEnemyEdit){
        if(sender.scale > 1.0f){
            renderer->enemyScaleFactor += sender.scale / 100.0f;
        } else if(sender.scale < 1.0f){
            renderer->enemyScaleFactor -= (2 - sender.scale) / 100.0f;
        }
    }
}

- (void)swipeToMoveEnemy:(UIPanGestureRecognizer *)sender{
    CGPoint velocity = [sender velocityInView:self.view];
    if(renderer->enableEnemyEdit){
        renderer->enemyScreenMoveY += -velocity.y / 20000.0f;
        renderer->enemyScreenMoveZ -= velocity.x / 20000.0f * sinf(renderer->viewRotateY);
        renderer->enemyScreenMoveX += velocity.x / 20000.0f * cosf(renderer->viewRotateY);
    }
}

- (void)swipeUpToMovePositive:(UISwipeGestureRecognizer *)sender{
    if(renderer->enableEnemyEdit){
        if(axis == 0){
            renderer->enemyMoveX += 0.2f;
        }
        else if(axis == 1){
            renderer->enemyMoveY += 0.2f;
        }
        else if(axis == 2){
            renderer->enemyMoveZ += 0.2f;
        }
        NSLog(@"swiping up");
    }
}

- (void)swipeDownToMoveNegative:(UISwipeGestureRecognizer *)sender{
        if(renderer->enableEnemyEdit){
        if(axis == 0){
            renderer->enemyMoveX -= 0.2f;
        }
        else if(axis == 1){
            renderer->enemyMoveY -= 0.2f;
        }
        else if(axis == 2){
            renderer->enemyMoveZ -= 0.2f;
        }
            NSLog(@"swiping down");
    }
}
@end
