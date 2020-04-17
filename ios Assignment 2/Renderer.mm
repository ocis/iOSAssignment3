//
//  Copyright © Borna Noureddin. All rights reserved.
//

#import "Renderer.h"
#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#include <chrono>
#include "GLESRenderer.hpp"
#include "maze.h"



//===========================================================================
//  GL uniforms, attributes, etc.

// List of uniform values used in shaders
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_TEXTURE,
    UNIFORM_MODELVIEW_MATRIX,
    // ### Add uniforms for lighting parameters here...
    UNIFORM_FLASHLIGHT_POSITION,
    UNIFORM_DIFFUSE_LIGHT_POSITION,
    UNIFORM_SHININESS,
    UNIFORM_AMBIENT_COMPONENT,
    UNIFORM_DIFFUSE_COMPONENT,
    UNIFORM_SPECULAR_COMPONENT,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// List of vertex attributes
enum
{
    ATTRIB_POSITION,
    ATTRIB_NORMAL,
    ATTRIB_TEXTURE_COORDINATE,
    NUM_ATTRIBUTES
};

#define BUFFER_OFFSET(i) ((char *)NULL + (i))



//===========================================================================
//  Class interface
@interface Renderer () {
    
    // iOS hooks
    GLKView *theView;
    
    
    // GL ES variables
    GLESRenderer glesRenderer;
    GLuint _program;
    GLuint crateTexture;
    GLuint leftWallTexture;
    GLuint rightWallTexture;
    GLuint bothWallsTexture;
    GLuint noWallsTexture;
    GLuint floorTexture;
    GLuint ghostTexture;
    
    // GLES buffer IDs
    GLuint _vertexArray;
    GLuint _vertexBuffers[3];
    GLuint _indexBuffer;
    
    // GLES buffer IDs for Enemy Cube
    GLuint _vertexArrayForEnemy;
    GLuint _indexBufferForEnemy;
    
    // GLES buffer IDs for Walls
    GLuint _vertexArrayForWalls;
    GLuint _indexBufferforWalls;
    
    // GLES buffer IDs for Marker
    GLuint _vertexArrayForMarker;
    GLuint _indexBufferforMarker;
    
    // Transformation matrices
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    GLKMatrix4 _modelViewMatrix;
    
    // Lighting parameters
    // ### Add lighting parameter variables here...
    GLKVector3 flashlightPosition;
    GLKVector3 diffuseLightPosition;
    GLKVector4 diffuseComponent;
    float shininess;
    GLKVector4 specularComponent;
    GLKVector4 ambientComponent;
    
    
    // Model
    float *vertices, *normals, *texCoords;
    GLuint *indices, numIndices, numWallIndices, numMarkerIndices, numEnemyIndices;
    
    
    // Misc UI variables
    std::chrono::time_point<std::chrono::steady_clock> lastTime;
    float minimapScale;
    // Maze
    Maze maze;
    int mazeSize;
    float floorDistance;
    float mazeDistance;
    
    bool mazeDrawn;
}

@end



//===========================================================================
//  Class implementation
@implementation Renderer

// UI properties
@synthesize isRotating;
@synthesize rotAngle, xRot, yRot;


//=======================
// Initial setup of GL using iOS view
//=======================
- (void)setup:(GLKView *)view
{
    // Create GL context
    view.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (!view.context) {
        NSLog(@"Failed to create ES context");
    }
    
    // Set up context
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    theView = view;
    [EAGLContext setCurrentContext:view.context];
    
    // Load in and set up shaders
    if (![self setupShaders])
        return;
    
    
    
    // Initialize UI element variables
    rotAngle = 0.0f;
    isRotating = 1;
    
    // Initialize distances
    floorDistance = 0.4999f;
    mazeDistance = -2;
    mazeDrawn = false;
    
    // Initialize view transformation variables
    viewRotateX = 0.0f;
    viewRotateY = 0.0f;
    viewRotateZ = 0.0f;
    viewTranslateX = 0.0f;
    viewTranslateY = 0.0f;
    viewTranslateZ = 0.0f;
    
    minimapViewRotateX = 0.0f;
    minimapViewRotateY = 0.0f;
    minimapViewRotateZ = 0.0f;
    minimapTranslateX = 0.0f;
    minimapTranslateY = 0.0f;
    minimapTranslateZ = 0.0f;
    minimapScale = 1.0f;
    enableMap = false;
    
    // Initialize enemy vars
    enemyMoveX = 0.0f;
    enemyMoveY = 0.0f;
    enemyMoveZ = 0.0f;
    enemyScreenMoveX = 0.0f;
    enemyScreenMoveY = 0.0f;
    enemyScreenMoveZ = 0.0f;
    enemyRotateY = 0.0f;
    enemyScreenRotateX = 0.0f;
    enemyScreenRotateXFactor = 1.0f;
    enemyScreenRotateZFactor = 0.0f;
    enemyScreenRotateY = 0.0f;
    enemyScaleFactor = 1.0f;
    enableEnemyEdit = false;
    
    // Initialize GL color and other parameters
    glClearColor ( 0.0f, 0.0f, 0.0f, 0.0f );
    glEnable(GL_DEPTH_TEST);
    lastTime = std::chrono::steady_clock::now();
    
}
//=========================
// Resets all the changes made to the enemy in edit mode
//=========================
- (void)resetEdits{
    enemyMoveY = 0.0f;
    enemyScreenMoveX = 0.0f;
    enemyScreenMoveY = 0.0f;
    enemyScreenMoveZ = 0.0f;
    enemyRotateY = 0.0f;
    enemyScreenRotateX = 0.0f;
    enemyScreenRotateXFactor = 1.0f;
    enemyScreenRotateZFactor = 0.0f;
    enemyScreenRotateY = 0.0f;
    enemyScaleFactor = 1.0f;
}
//=======================
// Load and set up shaders
//=======================
- (bool)setupShaders
{
    // Load shaders
    char *vShaderStr = glesRenderer.LoadShaderFile([[[NSBundle mainBundle] pathForResource:[[NSString stringWithUTF8String:"Shader.vsh"] stringByDeletingPathExtension] ofType:[[NSString stringWithUTF8String:"Shader.vsh"] pathExtension]] cStringUsingEncoding:1]);
    char *fShaderStr = glesRenderer.LoadShaderFile([[[NSBundle mainBundle] pathForResource:[[NSString stringWithUTF8String:"Shader.fsh"] stringByDeletingPathExtension] ofType:[[NSString stringWithUTF8String:"Shader.fsh"] pathExtension]] cStringUsingEncoding:1]);
    
    _program = glesRenderer.LoadProgram(vShaderStr, fShaderStr);
    if (_program == 0)
        return false;
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, ATTRIB_POSITION, "position");
    glBindAttribLocation(_program, ATTRIB_NORMAL, "normal");
    glBindAttribLocation(_program, ATTRIB_TEXTURE_COORDINATE, "texCoordIn");
    
    // Link shader program
    _program = glesRenderer.LinkProgram(_program);
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    uniforms[UNIFORM_MODELVIEW_MATRIX] = glGetUniformLocation(_program, "modelViewMatrix");
    uniforms[UNIFORM_TEXTURE] = glGetUniformLocation(_program, "texSampler");
    // ### Add lighting uniform locations here...
    uniforms[UNIFORM_FLASHLIGHT_POSITION] = glGetUniformLocation(_program, "flashlightPosition");
    uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION] = glGetUniformLocation(_program, "diffuseLightPosition");
    uniforms[UNIFORM_SHININESS] = glGetUniformLocation(_program, "shininess");
    uniforms[UNIFORM_AMBIENT_COMPONENT] = glGetUniformLocation(_program, "ambientComponent");
    uniforms[UNIFORM_DIFFUSE_COMPONENT] = glGetUniformLocation(_program, "diffuseComponent");
    uniforms[UNIFORM_SPECULAR_COMPONENT] = glGetUniformLocation(_program, "specularComponent");
    
    // Set up lighting parameters
    // ### Set default lighting parameter values here...
    flashlightPosition = GLKVector3Make(0.0, 0.0, 1.0);
    diffuseLightPosition = GLKVector3Make(0.0, 1.0, 0.0);
    diffuseComponent = GLKVector4Make(0.8, 0.1, 0.1, 1.0);
    shininess = 200.0;
    specularComponent = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
    ambientComponent = GLKVector4Make(0.2, 0.2, 0.2, 1.0);
    
    return true;
}


//=======================
// Loads cube model
//=======================
- (void)loadModels
{
    // Create VAOs
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    
    // Create VBOs
    glGenBuffers(NUM_ATTRIBUTES, _vertexBuffers);   // One buffer for each attribute
    glGenBuffers(1, &_indexBuffer);                 // Index buffer
    
    // Generate vertex attribute values from model
    int numVerts;
    numIndices = glesRenderer.GenCube(1.0f, &vertices, &normals, &texCoords, &indices, &numVerts);
    
    // Set up VBOs...
    
    // Position
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, vertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_POSITION);
    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    // Normal vector
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, normals, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_NORMAL);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    // Texture coordinate
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, texCoords, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_TEXTURE_COORDINATE);
    glVertexAttribPointer(ATTRIB_TEXTURE_COORDINATE, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), BUFFER_OFFSET(0));
    
    
    // Set up index buffer
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*numIndices, indices, GL_STATIC_DRAW);
    
    // Reset VAO
    glBindVertexArray(0);
    
    // Load texture to apply and set up texture in GL
    crateTexture = [self setupTexture:@"crate.jpg"];
}
//=======================
// Loads enemy model
//=======================
- (void)loadEnemyModel
{
    // Create VAOs
    glGenVertexArrays(1, &_vertexArrayForEnemy);
    glBindVertexArray(_vertexArrayForEnemy);
    
    // Create VBOs
    glGenBuffers(NUM_ATTRIBUTES, _vertexBuffers);   // One buffer for each attribute
    glGenBuffers(1, &_indexBufferForEnemy);                 // Index buffer
    
    // Generate vertex attribute values from model
    int numVerts;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"boxModel" ofType:@"custom"];
    const char *modelFileName = [path UTF8String];
    
    numEnemyIndices = glesRenderer.GenEnemyCube(0.25f, &vertices, &normals, &texCoords, &indices, &numVerts, modelFileName);
    
    // Set up VBOs...
    
    // Position
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, vertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_POSITION);
    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    // Normal vector
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, normals, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_NORMAL);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    // Texture coordinate
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, texCoords, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_TEXTURE_COORDINATE);
    glVertexAttribPointer(ATTRIB_TEXTURE_COORDINATE, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), BUFFER_OFFSET(0));
    
    
    // Set up index buffer
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferForEnemy);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*numEnemyIndices, indices, GL_STATIC_DRAW);
    
    // Reset VAO
    glBindVertexArray(0);
    
    ghostTexture = [self setupTexture:@"ghost.jpg"];

}

//=======================
// Loads wall tile model
//=======================
- (void)loadWallModel
{
    // Create VAOs
    glGenVertexArrays(1, &_vertexArrayForWalls);
    glBindVertexArray(_vertexArrayForWalls);
    
    // Create VBOs
    glGenBuffers(NUM_ATTRIBUTES, _vertexBuffers);   // One buffer for each attribute
    glGenBuffers(1, &_indexBufferforWalls);                 // Index buffer
    
    // Generate vertex attribute values from model
    int numVerts;
    numWallIndices = glesRenderer.GenWall(1.0f, &vertices, &normals, &texCoords, &indices, &numVerts);
    
    // Set up VBOs...
    
    // Position
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, vertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_POSITION);
    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    // Normal vector
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, normals, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_NORMAL);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    // Texture coordinate
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, texCoords, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_TEXTURE_COORDINATE);
    glVertexAttribPointer(ATTRIB_TEXTURE_COORDINATE, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), BUFFER_OFFSET(0));
    
    
    // Set up index buffer
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*numWallIndices, indices, GL_STATIC_DRAW);
    
    // Reset VAO
    glBindVertexArray(0);
    
    // Load texture to apply and set up texture in GL
    leftWallTexture = [self setupTexture:@"brickTexture.jpg"];
    rightWallTexture = [self setupTexture:@"drywallTexture.jpg"];
    bothWallsTexture = [self setupTexture:@"greywallTexture.jpg"];
    noWallsTexture = [self setupTexture:@"stonewallTexture.jpg"];
    floorTexture = [self setupTexture:@"grassTexture.jpg"];
    
}

//=======================
// Loads minimap marker for player model
//=======================
- (void)loadMarkerModel
{
    // Create VAOs
    glGenVertexArrays(1, &_vertexArrayForMarker);
    glBindVertexArray(_vertexArrayForMarker);
    
    // Create VBOs
    glGenBuffers(NUM_ATTRIBUTES, _vertexBuffers);   // One buffer for each attribute
    glGenBuffers(1, &_indexBufferforMarker);                 // Index buffer
    
    // Generate vertex attribute values from model
    int numVerts;
    numMarkerIndices = glesRenderer.GenMarker(1.0f, &vertices, &normals, &texCoords, &indices, &numVerts);
    
    // Set up VBOs...
    
    // Position
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, vertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_POSITION);
    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    // Normal vector
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, normals, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_NORMAL);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    // Texture coordinate
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, texCoords, GL_STATIC_DRAW);
    glEnableVertexAttribArray(ATTRIB_TEXTURE_COORDINATE);
    glVertexAttribPointer(ATTRIB_TEXTURE_COORDINATE, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), BUFFER_OFFSET(0));
    
    
    // Set up index buffer
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforMarker);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*numMarkerIndices, indices, GL_STATIC_DRAW);
    
    // Reset VAO
    glBindVertexArray(0);
    
    // Load texture to apply and set up texture in GL
    
}
//=======================
// Load in and set up texture image (adapted from Ray Wenderlich)
//=======================
- (GLuint)setupTexture:(NSString *)fileName
{
    CGImageRef spriteImage = [UIImage imageNamed:fileName].CGImage;
    if (!spriteImage) {
        NSLog(@"Failed to load image %@", fileName);
        exit(1);
    }
    
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte *spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    GLuint texName;
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    free(spriteData);
    return texName;
}

//=======================
// Clean up code before deallocating renderer object
//=======================
- (void)dealloc
{
    // Delete GL buffers
    glDeleteBuffers(3, _vertexBuffers);
    glDeleteBuffers(1, &_indexBuffer);
    glDeleteVertexArrays(1, &_vertexArray);
    
    // Delete vertices buffers
    if (vertices)
        free(vertices);
    if (indices)
        free(indices);
    if (normals)
        free(normals);
    if (texCoords)
        free(texCoords);
    
    // Delete shader program
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}


//=======================
// Update each frame (updates the rotation of the cube)
//=======================
- (void)update
{
    // Calculate elapsed time
    auto currentTime = std::chrono::steady_clock::now();
    auto elapsedTime = std::chrono::duration_cast<std::chrono::milliseconds>(currentTime - lastTime).count();
    lastTime = currentTime;
    
    // Do UI tasks
    if (isRotating)
    {
        rotAngle += 0.001f * elapsedTime;
        if (rotAngle >= 360.0f)
            rotAngle = 0.0f;
    }
    
    // Set up base model view matrix (place camera)
    GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(1.1f, 0.0f + viewTranslateY, mazeDistance);
    
    modelMatrix = GLKMatrix4Rotate(modelMatrix, xRot, 1.0f, 0.0f, 0.0f);
    modelMatrix = GLKMatrix4Rotate(modelMatrix, yRot, 0.0f, 1.0f, 0.0f);
    modelMatrix = GLKMatrix4Rotate(modelMatrix, rotAngle, 0.0f, 1.0f, 0.0f);
    
    // Set up model view matrix (place model in world)
    GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(viewTranslateX, 0.0f,viewTranslateZ);
    GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, -viewRotateY, 0.0f, 1.0f, 0.0f);
    viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
    
    _modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
    
    // Calculate normal matrix
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(_modelViewMatrix), NULL);
    
    // Calculate projection matrix
    float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    // Calculate model-view-projection matrix
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, _modelViewMatrix);
}


//=======================
// Draw calls for each frame
//=======================
- (void)draw:(CGRect)drawRect
{
    // Clear window
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // BELOW IS FOR DRAWING CUBE ==================================
    // Select VAO and shaders
    glBindVertexArray(_vertexArray);
    glUseProgram(_program);
    
    // Apply texture to next drawn object
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, crateTexture);
    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
    
    // Set up uniforms
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _modelViewMatrix.m);
    
    // ### Set values for lighting parameter uniforms here...
    glUniform3fv(uniforms[UNIFORM_FLASHLIGHT_POSITION], 1, flashlightPosition.v);
    glUniform3fv(uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION], 1, diffuseLightPosition.v);
    glUniform4fv(uniforms[UNIFORM_DIFFUSE_COMPONENT], 1, diffuseComponent.v);
    glUniform1f(uniforms[UNIFORM_SHININESS], shininess);
    glUniform4fv(uniforms[UNIFORM_SPECULAR_COMPONENT], 1, specularComponent.v);
    glUniform4fv(uniforms[UNIFORM_AMBIENT_COMPONENT], 1, ambientComponent.v);
    
    // Select VBO and draw
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_INT, 0);
    // ABOVE IS DRAWING A SINGLE CUBE ==================================
    
    // DRAWING ENEMY CUBE
    glBindVertexArray(_vertexArrayForEnemy);
    glUseProgram(_program);
    
    // Apply texture to next drawn object
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, ghostTexture);
    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
    
    // Set upmodel matrix (place wall in world)
    GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(enemyMoveX + enemyScreenMoveX, enemyMoveY + enemyScreenMoveY, enemyMoveZ + enemyScreenMoveZ + mazeDistance);
    
    modelMatrix = GLKMatrix4Scale(modelMatrix, enemyScaleFactor, enemyScaleFactor, enemyScaleFactor);
    
    modelMatrix = GLKMatrix4Rotate(modelMatrix, enemyScreenRotateX, enemyScreenRotateXFactor, 0.0f, enemyScreenRotateZFactor);
    
    modelMatrix = GLKMatrix4Rotate(modelMatrix, enemyScreenRotateY, 0.0f, 1.0f, 0.0f);
    
    // Set up view matrix (place camera position)
    GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(viewTranslateX, 0.0f,viewTranslateZ);
    GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, -viewRotateY, 0.0f, 1.0f, 0.0f);
    viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
    
    // Calculate normal matrix
    GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    // Calculate projection matrix
    float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    // Calculate model-view-projection matrix
    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferForEnemy);
    glDrawElements(GL_TRIANGLES, numEnemyIndices, GL_UNSIGNED_INT, 0);
    // DONE DRAWING ENEMY CUBE=================================================
    
    if(!mazeDrawn){
        [self initMaze];
        mazeDrawn = true;
    }
    //=======================
    // BELOW STEPS THROUGH THE MAZE AND GENERATES THE WALL AND FLOOR TILES
    //=======================
    // Select vertex array for wall model and loads it into gpu
    glBindVertexArray(_vertexArrayForWalls);
    glUseProgram(_program);
    
    int i = maze.rows;
    int j = maze.cols;
    
    //Step through and generation of maze tiles below
    //=================================================
    for(i = 0; i < maze.rows; i++){
        for(j = 0; j < maze.cols; j++){
            MazeCell cell = maze.GetCell(i, j);
            // For north wall ============
            //=============================
            if(cell.northWallPresent){
                if(cell.eastWallPresent){
                    if(cell.westWallPresent){
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, bothWallsTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    } else{
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, leftWallTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    }
                } else if(cell.westWallPresent){
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, rightWallTexture);
                    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                } else{
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, noWallsTexture);
                    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                }
                // Set upmodel matrix (place wall in world)
                GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j, 0.0f, -i + mazeDistance + floorDistance);
                
                // Set up view matrix (place camera position)
                GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(viewTranslateX, 0.0f,viewTranslateZ);
                GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, -viewRotateY, 0.0f, 1.0f, 0.0f);
                viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
                
                GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
                
                // Calculate normal matrix
                GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                
                // Calculate projection matrix
                float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
                GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
                
                // Calculate model-view-projection matrix
                GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
                
                // Select VBO and draw
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
                glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
            }
            // For east wall ============
            //===========================
            if(cell.eastWallPresent){
                if(cell.southWallPresent){
                    if(cell.northWallPresent){
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, bothWallsTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    } else{
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, leftWallTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    }
                } else if(cell.northWallPresent){
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, rightWallTexture);
                    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                } else{
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, noWallsTexture);
                    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                }
                // Set up base model matrix
                GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j - floorDistance, 0.0f, -i + mazeDistance);
                modelMatrix = GLKMatrix4Rotate(modelMatrix, M_PI_2, 0.0f, 1.0f, 0.0f);
                
                // Set up model view matrix
                GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(viewTranslateX, 0.0f,viewTranslateZ);
                GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, -viewRotateY, 0.0f, 1.0f, 0.0f);
                viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
                
                GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
                
                // Calculate normal matrix
                GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                
                // Calculate projection matrix
                float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
                GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
                
                // Calculate model-view-projection matrix
                GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
                
                // Select VBO and draw
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
                glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
            }
            // For west wall ============
            //===============================
            if(cell.westWallPresent){
                if(cell.northWallPresent){
                    if(cell.southWallPresent){
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, bothWallsTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    } else{
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, leftWallTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    }
                } else if(cell.southWallPresent){
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, rightWallTexture);
                    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                } else{
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, noWallsTexture);
                    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                }
                // Set up base model matrix
                GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j + floorDistance, 0.0f, -i + mazeDistance);
                modelMatrix = GLKMatrix4Rotate(modelMatrix, M_PI_2, 0.0f, 1.0f, 0.0f);
                
                // Set up model view matrix
                GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(viewTranslateX, 0.0f,viewTranslateZ);
                GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, -viewRotateY, 0.0f, 1.0f, 0.0f);
                viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
                
                GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
                
                // Calculate normal matrix
                GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                
                // Calculate projection matrix
                float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
                GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
                
                // Calculate model-view-projection matrix
                GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
                
                // Select VBO and draw
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
                glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
            }
            // For south wall ============
            //=============================
            if(cell.southWallPresent){
                if(cell.westWallPresent){
                    if(cell.eastWallPresent){
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, bothWallsTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    } else{
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, leftWallTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    }
                } else if(cell.eastWallPresent){
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, rightWallTexture);
                    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                } else{
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, noWallsTexture);
                    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                }
                // Set up base model matrix
                GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j, 0.0f, -i + mazeDistance - floorDistance);
                
                // Set up view matrix
                GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(viewTranslateX, 0.0f,viewTranslateZ);
                GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, -viewRotateY, 0.0f, 1.0f, 0.0f);
                viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
                
                GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
                
                // Calculate normal matrix
                GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                
                // Calculate projection matrix
                float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
                GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
                
                // Calculate model-view-projection matrix
                GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
                
                // Select VBO and draw
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
                glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
            }
            //=====Drawing floor tile===================
            //==========================================
            
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, floorTexture);
            glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
            
            // Set up model matrix
            GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j, -floorDistance, -i + mazeDistance);
            modelMatrix = GLKMatrix4Rotate(modelMatrix, M_PI_2, 1.0f, 0.0f, 0.0f);
            
            // Set up view matrix
            GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(viewTranslateX, 0.0f,viewTranslateZ);
            GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, -viewRotateY, 0.0f, 1.0f, 0.0f);
            viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
            
            GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
            
            // Calculate normal matrix
            GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
            
            // Calculate projection matrix
            float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
            GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
            
            // Calculate model-view-projection matrix
            GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
            
            // Select VBO and draw
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
            glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
        }
    }
    //==========ABOVE IS FOR DRAWING THE MAZE IN THE WORLD==========
    
    
    //====DRAWING MINIMAP============================================
    // BASICALLY THE SAME AS DRAWING THE MAZE IN THE WORLD BUT WITH THE VIEW
    // MATRIX BEING ADAPTED TO AN OVERHEAD VIEW, AND APPLYING APPROPRIATE TRANSFORMATIONS
    // TO THE MINIMAP MARKER OBJECT, WHICH GETS GENERATED HERE AND NOT ABOVE.
    // DEPTH CHECK IS DISABLED FOR MINIMAP DRAWING OTHERWISE WEIRD CRAP HAPPENS
    // BLENDING IS ENABLED SO THAT ALPHA IN THE SHADER IS USED WHICH ALLOWS FOR TRANSPARENCY
    //============================================================================
    if(enableMap){
        glDepthFunc(GL_FALSE);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
        // Stepping through and drawing the maze walls ====================
        glBindVertexArray(_vertexArrayForWalls);
        glUseProgram(_program);
        
        for(i = 0; i < maze.rows; i++){
            for(j = 0; j < maze.cols; j++){
                MazeCell cell = maze.GetCell(i, j);
                // For north wall ============
                //=============================
                if(cell.northWallPresent){
                    if(cell.eastWallPresent){
                        if(cell.westWallPresent){
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, bothWallsTexture);
                            glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                        } else{
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, leftWallTexture);
                            glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                        }
                    } else if(cell.westWallPresent){
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, rightWallTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    } else{
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, noWallsTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    }
                    GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j, 0.0f, -i + mazeDistance + floorDistance);
                    GLKMatrix4 scaleMatrix = GLKMatrix4Scale(GLKMatrix4Identity, minimapScale, minimapScale, minimapScale);
                    
                    modelMatrix = GLKMatrix4Multiply(scaleMatrix, modelMatrix);
                    
                    GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(minimapTranslateX, minimapTranslateY,minimapTranslateZ);
                    GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, minimapViewRotateX, 1.0f, 0.0f, 0.0f);
                    viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
                    
                    GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
                    
                    // Calculate normal matrix
                    GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                    
                    // Calculate projection matrix
                    float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
                    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
                    
                    // Calculate model-view-projection matrix
                    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                    [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
                    
                    // Select VBO and draw
                    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
                    glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
                }
                // For east wall ============
                //===========================
                if(cell.eastWallPresent){
                    if(cell.southWallPresent){
                        if(cell.northWallPresent){
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, bothWallsTexture);
                            glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                        } else{
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, leftWallTexture);
                            glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                        }
                    } else if(cell.northWallPresent){
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, rightWallTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    } else{
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, noWallsTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    }
                    
                    GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j - floorDistance, 0.0f, -i + mazeDistance);
                    modelMatrix = GLKMatrix4Rotate(modelMatrix, M_PI_2, 0.0f, 1.0f, 0.0f);
                    
                    GLKMatrix4 scaleMatrix = GLKMatrix4Scale(GLKMatrix4Identity, minimapScale, minimapScale, minimapScale);
                    
                    modelMatrix = GLKMatrix4Multiply(scaleMatrix, modelMatrix);
                    
                    GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(minimapTranslateX, minimapTranslateY,minimapTranslateZ);
                    GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, minimapViewRotateX, 1.0f, 0.0f, 0.0f);
                    
                    viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
                    
                    GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
                    
                    // Calculate normal matrix
                    GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                    
                    // Calculate projection matrix
                    float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
                    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
                    
                    // Calculate model-view-projection matrix
                    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                    [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
                    
                    // Select VBO and draw
                    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
                    glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
                }
                // For west wall ============
                //===============================
                if(cell.westWallPresent){
                    if(cell.northWallPresent){
                        if(cell.southWallPresent){
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, bothWallsTexture);
                            glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                        } else{
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, leftWallTexture);
                            glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                        }
                    } else if(cell.southWallPresent){
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, rightWallTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    } else{
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, noWallsTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    }
                    GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j + floorDistance, 0.0f, -i + mazeDistance);
                    modelMatrix = GLKMatrix4Rotate(modelMatrix, M_PI_2, 0.0f, 1.0f, 0.0f);
                    
                    GLKMatrix4 scaleMatrix = GLKMatrix4Scale(GLKMatrix4Identity, minimapScale, minimapScale, minimapScale);
                    
                    modelMatrix = GLKMatrix4Multiply(scaleMatrix, modelMatrix);
                    
                    GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(minimapTranslateX, minimapTranslateY,minimapTranslateZ);
                    GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, minimapViewRotateX, 1.0f, 0.0f, 0.0f);
                    
                    viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
                    
                    GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
                    
                    // Calculate normal matrix
                    GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                    
                    // Calculate projection matrix
                    float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
                    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
                    
                    // Calculate model-view-projection matrix
                    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                    [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
                    
                    // Select VBO and draw
                    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
                    glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
                }
                // For south wall ============
                //=============================
                if(cell.southWallPresent){
                    if(cell.westWallPresent){
                        if(cell.eastWallPresent){
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, bothWallsTexture);
                            glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                        } else{
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, leftWallTexture);
                            glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                        }
                    } else if(cell.eastWallPresent){
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, rightWallTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    } else{
                        glActiveTexture(GL_TEXTURE0);
                        glBindTexture(GL_TEXTURE_2D, noWallsTexture);
                        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                    }
                    GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j, 0.0f, -i + mazeDistance - floorDistance);
                    
                    GLKMatrix4 scaleMatrix = GLKMatrix4Scale(GLKMatrix4Identity, minimapScale, minimapScale, minimapScale);
                    
                    modelMatrix = GLKMatrix4Multiply(scaleMatrix, modelMatrix);
                    
                    GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(minimapTranslateX, minimapTranslateY,minimapTranslateZ);
                    GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, minimapViewRotateX, 1.0f, 0.0f, 0.0f);
                    
                    viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
                    
                    GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
                    
                    // Calculate normal matrix
                    GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                    
                    // Calculate projection matrix
                    float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
                    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
                    
                    // Calculate model-view-projection matrix
                    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                    [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
                    
                    // Select VBO and draw
                    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
                    glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
                }
                //=====Drawing floor tile===================
                //==========================================
                
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, floorTexture);
                glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
                
                // Set up base model view matrix (place camera)
                GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-j, -floorDistance, -i + mazeDistance);
                modelMatrix = GLKMatrix4Rotate(modelMatrix, M_PI_2, 1.0f, 0.0f, 0.0f);
                
                GLKMatrix4 scaleMatrix = GLKMatrix4Scale(GLKMatrix4Identity, minimapScale, minimapScale, minimapScale);
                
                modelMatrix = GLKMatrix4Multiply(scaleMatrix, modelMatrix);
                
                // Set up model view matrix (place model in world)
                GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(minimapTranslateX, minimapTranslateY,minimapTranslateZ);
                GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, minimapViewRotateX, 1.0f, 0.0f, 0.0f);
                
                viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
                
                GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
                
                // Calculate normal matrix
                GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                
                // Calculate projection matrix
                float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
                GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
                
                // Calculate model-view-projection matrix
                GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
                
                // Select VBO and draw
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
                glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
                
                
            }
        }
        //============Drawing marker===============
        //==========================================
        glBindVertexArray(_vertexArrayForMarker);
        glUseProgram(_program);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, rightWallTexture);
        glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
        
        GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-viewTranslateX * (2), -floorDistance + minimapScale, -viewTranslateZ * (2) + (mazeDistance / maze.cols));
        modelMatrix = GLKMatrix4Rotate(modelMatrix, M_PI_2, 1.0f, 0.0f, 0.0f);
        modelMatrix = GLKMatrix4Rotate(modelMatrix, M_PI, 0.0f, 0.0f, 1.0f);
        modelMatrix = GLKMatrix4Rotate(modelMatrix, -viewRotateY, 0.0f, 0.0f, 1.0f);
        
        GLKMatrix4 scaleMatrix = GLKMatrix4Scale(GLKMatrix4Identity, minimapScale / 2, minimapScale / 2, minimapScale / 2);
        
        modelMatrix = GLKMatrix4Multiply(scaleMatrix, modelMatrix);
        
        GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(minimapTranslateX, minimapTranslateY,minimapTranslateZ);
        GLKMatrix4 rotationMatrix = GLKMatrix4Rotate(GLKMatrix4Identity, minimapViewRotateX, 1.0f, 0.0f, 0.0f);
        
        viewMatrix = GLKMatrix4Multiply(rotationMatrix, viewMatrix);
        
        GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
        
        // Calculate normal matrix
        GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
        
        // Calculate projection matrix
        float aspect = fabsf(theView.bounds.size.width / theView.bounds.size.height);
        GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
        
        // Calculate model-view-projection matrix
        GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
        [self setUniforms:modelViewProjectionMatrix normalMatrix:normalMatrix modelViewMatrix:modelViewMatrix];
        
        // Select VBO and draw
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferforWalls);
        glDrawElements(GL_TRIANGLES, numWallIndices, GL_UNSIGNED_INT, 0);
        
        glDisable(GL_BLEND);
        glDepthFunc(GL_TRUE);
    }
}
- (void)setUniforms:(GLKMatrix4)_modelViewProjectionMatrix normalMatrix:(GLKMatrix3)_normalMatrix modelViewMatrix:(GLKMatrix4)_modelViewMatrix
{
    // Set up uniforms
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _modelViewMatrix.m);
    
    // ### Set values for lighting parameter uniforms here...
    glUniform3fv(uniforms[UNIFORM_FLASHLIGHT_POSITION], 1, flashlightPosition.v);
    glUniform3fv(uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION], 1, diffuseLightPosition.v);
    glUniform4fv(uniforms[UNIFORM_DIFFUSE_COMPONENT], 1, diffuseComponent.v);
    glUniform1f(uniforms[UNIFORM_SHININESS], shininess);
    glUniform4fv(uniforms[UNIFORM_SPECULAR_COMPONENT], 1, specularComponent.v);
    glUniform4fv(uniforms[UNIFORM_AMBIENT_COMPONENT], 1, ambientComponent.v);
}

- (void)initMaze{
    maze.Create();
    
    minimapViewRotateX = M_PI_2;
    minimapViewRotateY = 0.0f;
    minimapViewRotateZ = 0.0f;
    minimapTranslateX = 0.01f;
    minimapTranslateY = -0.1f;
    minimapTranslateZ = 0.01f;
    minimapScale = 0.01f;
}

@end

