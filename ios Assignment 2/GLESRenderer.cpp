//
//  Copyright © Borna Noureddin. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <iostream>
#include <math.h>
#include "GLESRenderer.hpp"
#include <vector>
#include "glm/glm.hpp"


char *GLESRenderer::LoadShaderFile(const char *shaderFileName)
{
    FILE *fp = fopen(shaderFileName, "rb");
    if (fp == NULL)
        return NULL;

    fseek(fp , 0 , SEEK_END);
    long totalBytes = ftell(fp);
    fclose(fp);

    char *buf = (char *)malloc(totalBytes+1);
    memset(buf, 0, totalBytes+1);

    fp = fopen(shaderFileName, "rb");
    if (fp == NULL)
        return NULL;

    size_t bytesRead = fread(buf, totalBytes, 1, fp);
    fclose(fp);
    if (bytesRead < 1)
        return NULL;

    return buf;
}

GLuint GLESRenderer::LoadShader(GLenum type, const char *shaderSrc)
{
    GLuint shader = glCreateShader(type);
    if (shader == 0)
        return 0;
    
    glShaderSource(shader, 1, &shaderSrc, NULL);
    glCompileShader(shader);

    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled)
    {
        GLint infoLen = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
        if (infoLen > 1)
        {
            char *infoLog = (char *)malloc(sizeof ( char ) * infoLen);
            glGetShaderInfoLog(shader, infoLen, NULL, infoLog);
            std::cerr << "*** SHADER COMPILE ERROR:" << std::endl;
            std::cerr << infoLog << std::endl;
            free(infoLog);
        }
        glDeleteShader ( shader );
        return 0;
    }
    
    return shader;
}

GLuint GLESRenderer::LoadProgram(const char *vertShaderSrc, const char *fragShaderSrc)
{
    vertexShader = LoadShader(GL_VERTEX_SHADER, vertShaderSrc);
    if (vertexShader == 0)
        return 0;
    
    fragmentShader = LoadShader(GL_FRAGMENT_SHADER, fragShaderSrc);
    if (fragmentShader == 0)
    {
        glDeleteShader(vertexShader);
        return 0;
    }
    
    GLuint programObject = glCreateProgram();
    if (programObject == 0)
    {
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
        return 0;
    }
    
    glAttachShader(programObject, vertexShader);
    glAttachShader(programObject, fragmentShader);

    return programObject;
}

GLuint GLESRenderer::LinkProgram(GLuint programObject)
{
    glLinkProgram(programObject);
    
    GLint linked;
    glGetProgramiv(programObject, GL_LINK_STATUS, &linked);
    if (!linked)
    {
        GLint infoLen = 0;
        glGetProgramiv(programObject, GL_INFO_LOG_LENGTH, &infoLen);
        if (infoLen > 1)
        {
            char *infoLog = (char *)malloc(sizeof(char) * infoLen);
            glGetProgramInfoLog(programObject, infoLen, NULL, infoLog);
            std::cerr << "*** SHADER LINK ERROR:" << std::endl;
            std::cerr << infoLog << std::endl;
            free(infoLog);
        }
        glDeleteProgram(programObject);
        return 0;
    }
    
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    return programObject;
}

// Generate vertices, normals, texture coordinates and indices for cube
// from a custom model file
//      Adapted from Dan Ginsburg, Budirijanto Purnomo from the book
//      OpenGL(R) ES 2.0 Programming Guide
int GLESRenderer::GenEnemyCube(float scale, GLfloat **vertices, GLfloat **normals,
                          GLfloat **texCoords, GLuint **indices, int *numVerts)
{
    int i;
    
    std::vector< float > enemyVerts, enemyTex, enemyNorms;
    std::vector< int > enemyIndices;
    std::vector< glm::vec3 > temp_verts;
    std::vector< glm::vec2 > temp_tex;
    std::vector< glm::vec3 > temp_norms;
    std::vector< glm::vec3 > temp_indeces;
    
    FILE * file = fopen("boxModel.custom", "r");
    
    if(file == NULL){
        printf("Can't open file");
        return -1;
    }
    
    while(1){
        char lineheader[128];
        
        int res = fscanf(file, "%s", lineheader);
        
        if(res == EOF){
            break;
        }
        
        if(strcmp(lineheader, "v") == 0){
            glm::vec3 vertex;
            fscanf(file, "%f, %f, %f\n", &vertex.x, &vertex.y, &vertex.z);
            enemyVerts.push_back(vertex.x);
            enemyVerts.push_back(vertex.y);
            enemyVerts.push_back(vertex.z);
        } else if(strcmp(lineheader, "vt") == 0){
            glm::vec2 tex;
            fscanf(file, "%f, %f\n", &tex.x, &tex.y);
            enemyTex.push_back(tex.x);
            enemyTex.push_back(tex.y);
        } else if(strcmp(lineheader, "vn") == 0){
            glm::vec3 norm;
            fscanf(file, "%f, %f, %f\n", &norm.x, &norm.y, &norm.z);
            enemyNorms.push_back(norm.x);
            enemyNorms.push_back(norm.y);
            enemyNorms.push_back(norm.z);
        }else if(strcmp(lineheader, "vi") == 0){
            glm::ivec3 index;
            fscanf(file, "%d, %d, %d\n", &index.x, &index.y, &index.z);
            enemyIndices.push_back(index.x);
            enemyIndices.push_back(index.y);
            enemyIndices.push_back(index.z);
        }
    }
    
    //=======================================
    
    GLfloat cubeVerts[enemyVerts.size()];
    std::copy(enemyVerts.begin(), enemyVerts.end(), cubeVerts);
    
    GLfloat cubeNormals[enemyNorms.size()];
    std::copy(enemyNorms.begin(), enemyNorms.end(), cubeNormals);
    
    GLfloat cubeTex[enemyTex.size()];
    std::copy(enemyTex.begin(), enemyTex.end(), cubeTex);
    
    GLuint cubeIndices[enemyIndices.size()];
    std::copy(enemyIndices.begin(), enemyIndices.end(), cubeIndices);
    
    int numVertices = static_cast<int>(enemyVerts.size()) / 3;
    int numIndices = static_cast<int>(enemyIndices.size()) / 3;
    
    // Allocate memory for buffers
    if ( vertices != NULL )
    {
        *vertices = (GLfloat *)malloc ( sizeof ( GLfloat ) * 3 * numVertices );
        memcpy ( *vertices, cubeVerts, sizeof ( cubeVerts ) );
        
        for ( i = 0; i < numVertices * 3; i++ )
        {
            ( *vertices ) [i] *= scale;
        }
    }
    
    if ( normals != NULL )
    {
        *normals = (GLfloat *)malloc ( sizeof ( GLfloat ) * 3 * numVertices );
        memcpy ( *normals, cubeNormals, sizeof ( cubeNormals ) );
    }
    
    if ( texCoords != NULL )
    {
        *texCoords = (GLfloat *)malloc ( sizeof ( GLfloat ) * 2 * numVertices );
        memcpy ( *texCoords, cubeTex, sizeof ( cubeTex ) ) ;
    }
    
    
    // Generate the indices
    if ( indices != NULL )
    {
        *indices = (GLuint *)malloc ( sizeof ( GLuint ) * numIndices );
        memcpy ( *indices, cubeIndices, sizeof ( cubeIndices ) );
    }
    
    if (numVerts != NULL)
        *numVerts = numVertices;
    return numIndices;
}

int GLESRenderer::GenCube(float scale, GLfloat **vertices, GLfloat **normals,
                          GLfloat **texCoords, GLuint **indices, int *numVerts)
{
    int i;
    int numVertices = 24;
    int numIndices = 36;
    
    GLfloat cubeVerts[] =
    {
        -0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f,  0.5f,
        0.5f, -0.5f,  0.5f,
        0.5f, -0.5f, -0.5f,
        -0.5f,  0.5f, -0.5f,
        -0.5f,  0.5f,  0.5f,
        0.5f,  0.5f,  0.5f,
        0.5f,  0.5f, -0.5f,
        -0.5f, -0.5f, -0.5f,
        -0.5f,  0.5f, -0.5f,
        0.5f,  0.5f, -0.5f,
        0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f, 0.5f,
        -0.5f,  0.5f, 0.5f,
        0.5f,  0.5f, 0.5f,
        0.5f, -0.5f, 0.5f,
        -0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f,  0.5f,
        -0.5f,  0.5f,  0.5f,
        -0.5f,  0.5f, -0.5f,
        0.5f, -0.5f, -0.5f,
        0.5f, -0.5f,  0.5f,
        0.5f,  0.5f,  0.5f,
        0.5f,  0.5f, -0.5f,
    };
    
    GLfloat cubeNormals[] =
    {
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
    };
    
    GLfloat cubeTex[] =
    {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    // Allocate memory for buffers
    if ( vertices != NULL )
    {
        *vertices = (GLfloat *)malloc ( sizeof ( GLfloat ) * 3 * numVertices );
        memcpy ( *vertices, cubeVerts, sizeof ( cubeVerts ) );
        
        for ( i = 0; i < numVertices * 3; i++ )
        {
            ( *vertices ) [i] *= scale;
        }
    }
    
    if ( normals != NULL )
    {
        *normals = (GLfloat *)malloc ( sizeof ( GLfloat ) * 3 * numVertices );
        memcpy ( *normals, cubeNormals, sizeof ( cubeNormals ) );
    }
    
    if ( texCoords != NULL )
    {
        *texCoords = (GLfloat *)malloc ( sizeof ( GLfloat ) * 2 * numVertices );
        memcpy ( *texCoords, cubeTex, sizeof ( cubeTex ) ) ;
    }
    
    
    // Generate the indices
    if ( indices != NULL )
    {
        GLuint cubeIndices[] =
        {
            0, 2, 1,
            0, 3, 2,
            4, 5, 6,
            4, 6, 7,
            8, 9, 10,
            8, 10, 11,
            12, 15, 14,
            12, 14, 13,
            16, 17, 18,
            16, 18, 19,
            20, 23, 22,
            20, 22, 21
        };
        
        *indices = (GLuint *)malloc ( sizeof ( GLuint ) * numIndices );
        memcpy ( *indices, cubeIndices, sizeof ( cubeIndices ) );
    }
    
    if (numVerts != NULL)
        *numVerts = numVertices;
    return numIndices;
}

int GLESRenderer::GenWall(float scale, GLfloat **vertices, GLfloat **normals, GLfloat **texCoords, GLuint **indices, int *numVerts){
    int i;
    int numVertices = 4;
    int numIndices = 6;
    
    GLfloat wallVerts[] =
    {
        -0.5f, -0.5f, 0.0f,
        -0.5f, 0.5f, 0.0f,
        0.5f, 0.5f, 0.0f,
        0.5f, -0.5f, 0.0f
    };
    
    GLfloat wallNormals[] =
    {
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, 1.0f
    };
    
    GLfloat wallTex[] =
    {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f
    };
    
    if (vertices != NULL)
    {
        *vertices = (GLfloat *)malloc (sizeof(GLfloat) * 3 * numVertices);
        memcpy(*vertices, wallVerts, sizeof(wallVerts));
        
        for(i = 0; i < numVertices * 3; i++)
        {
            (*vertices)[i] *= scale;
        }
    }
    
    if (normals != NULL)
    {
        *normals = (GLfloat *)malloc (sizeof(GLfloat) * 3 * numVertices);
        memcpy(*normals, wallNormals,   sizeof(wallNormals));
    }
    
    if(texCoords != NULL){
        *texCoords = (GLfloat *)malloc(sizeof(GLfloat) * 2 * numVertices);
        memcpy(*texCoords, wallTex, sizeof(wallTex));
    }
    
    if(indices != NULL){
        GLuint wallIndices[] =
        {
            0, 2, 1,
            0, 2, 3
        };
        *indices = (GLuint *)malloc(sizeof(GLuint) * numIndices);
        memcpy(*indices, wallIndices, sizeof(wallIndices));
    }
    
    if(numVerts != NULL)
        *numVerts = numVertices;
    return numIndices;
}

int GLESRenderer::GenMarker(float scale, GLfloat **vertices, GLfloat **normals, GLfloat **texCoords, GLuint **indices, int *numVerts){
    int i;
    int numVertices = 3;
    int numIndices = 3;
    
    GLfloat markerVerts[] =
    {
        -0.5f, -0.5f, 0.0f,
        0.0f, 0.5f, 0.0f,
        0.5f, -0.5f, 0.0f
    };
    
    GLfloat markerNorms[] =
    {
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, 1.0f
    };
    
    GLfloat markerTex[] =
    {
        0.0f, 0.0f,
        0.5f, 1.0f,
        1.0f, 1.0f,
    };
    
    if (vertices != NULL)
    {
        *vertices = (GLfloat *)malloc (sizeof(GLfloat) * 3 * numVertices);
        memcpy(*vertices, markerVerts, sizeof(markerVerts));
        
        for(i = 0; i < numVertices * 3; i++)
        {
            (*vertices)[i] *= scale;
        }
    }
    
    if (normals != NULL)
    {
        *normals = (GLfloat *)malloc (sizeof(GLfloat) * 3 * numVertices);
        memcpy(*normals, markerNorms,   sizeof(markerNorms));
    }
    
    if(texCoords != NULL){
        *texCoords = (GLfloat *)malloc(sizeof(GLfloat) * 2 * numVertices);
        memcpy(*texCoords, markerTex, sizeof(markerTex));
    }
    
    if(indices != NULL){
        GLuint markerIndices[] =
        {
            0, 2, 1,
        };
        *indices = (GLuint *)malloc(sizeof(GLuint) * numIndices);
        memcpy(*indices, markerIndices, sizeof(markerIndices));
    }
    
    if(numVerts != NULL)
        *numVerts = numVertices;
    return numIndices;
}

// Generate vertices, normals, texture coordinates and indices for sphere
//      Adapted from Dan Ginsburg, Budirijanto Purnomo from the book
//      OpenGL(R) ES 2.0 Programming Guide
int GLESRenderer::GenSphere(int numSlices, float radius, GLfloat **vertices,
                            GLfloat **normals, GLfloat **texCoords,
                            GLuint **indices, int *numVerts)
{
    int i;
    int j;
    int numParallels = numSlices / 2;
    int numVertices = ( numParallels + 1 ) * ( numSlices + 1 );
    int numIndices = numParallels * numSlices * 6;
    float angleStep = ( 2.0f * M_PI ) / ( ( float ) numSlices );
    
    // Allocate memory for buffers
    if ( vertices != NULL )
    {
        *vertices = (GLfloat *)malloc ( sizeof ( GLfloat ) * 3 * numVertices );
    }
    
    if ( normals != NULL )
    {
        *normals = (GLfloat *)malloc ( sizeof ( GLfloat ) * 3 * numVertices );
    }
    
    if ( texCoords != NULL )
    {
        *texCoords = (GLfloat *)malloc ( sizeof ( GLfloat ) * 2 * numVertices );
    }
    
    if ( indices != NULL )
    {
        *indices = (GLuint *)malloc ( sizeof ( GLuint ) * numIndices );
    }
    
    for ( i = 0; i < numParallels + 1; i++ )
    {
        for ( j = 0; j < numSlices + 1; j++ )
        {
            int vertex = ( i * ( numSlices + 1 ) + j ) * 3;
            
            if ( vertices )
            {
                ( *vertices ) [vertex + 0] = radius * sinf ( angleStep * ( float ) i ) *
                sinf ( angleStep * ( float ) j );
                ( *vertices ) [vertex + 1] = radius * cosf ( angleStep * ( float ) i );
                ( *vertices ) [vertex + 2] = radius * sinf ( angleStep * ( float ) i ) *
                cosf ( angleStep * ( float ) j );
            }
            
            if ( normals )
            {
                ( *normals ) [vertex + 0] = ( *vertices ) [vertex + 0] / radius;
                ( *normals ) [vertex + 1] = ( *vertices ) [vertex + 1] / radius;
                ( *normals ) [vertex + 2] = ( *vertices ) [vertex + 2] / radius;
            }
            
            if ( texCoords )
            {
                int texIndex = ( i * ( numSlices + 1 ) + j ) * 2;
                ( *texCoords ) [texIndex + 0] = ( float ) j / ( float ) numSlices;
                ( *texCoords ) [texIndex + 1] = ( 1.0f - ( float ) i ) / ( float ) ( numParallels - 1 );
            }
        }
    }
    
    // Generate the indices
    if ( indices != NULL )
    {
        GLuint *indexBuf = ( *indices );
        
        for ( i = 0; i < numParallels ; i++ )
        {
            for ( j = 0; j < numSlices; j++ )
            {
                *indexBuf++  = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                
                *indexBuf++ = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                *indexBuf++ = i * ( numSlices + 1 ) + ( j + 1 );
            }
        }
    }
    
    if (numVerts != NULL)
        *numVerts = numVertices;
    return numIndices;
}
