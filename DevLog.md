## 22 June 2025
Works...
Added Type Definitions of Vec2, Vec3, Entity, Chunk, ChunkData  
Added GL_STATE -> to effectively manage pages like menu, pause and game  
Added Player, Camera (follows player; CinematicCamera), SkyColor, Resizable Screen  
Added a Custom Parser to Parse Assets List  
Fixed a bug from previous versions: GL does not free texture memory -> Used \_glDeleteTextures  
Added FPSCounter, ErrHandlers  
Added Movement for Entities  
Added Chunk Loading Queue  
Added Debugging, Logging Commands  

## 23 June 2025
Works...
Added RenderDistance, calculated memory usage  
Added Basic Chunk System  
Created function for drawing text with font  
Currently Draws 1 Chunk, for testing  

## 24 June 2025
Works...
Improved Chunk System - Chunk Loading and Unloading  
Added 3D Noise  
Added Debug info for showing total chunks loaded, visible and total quads visible  
Added Ambient Occlusion  
Added Complex terrain generation  
Added Biomes  
Added Tons of blocks, and efficient block management  
Added Dynamic Skycolor  

## 25 June 2025
Works...  
Improved terrain generation  
Changed noise function  
Changed cube vertices data for GL_CULL_FACE  
Improved assets parser  
Reset to simple game  

## 26 June 2025
Fixed Bug for isTransparent()  
Fixed Bug after Turning off lighting  

## 01 July 2025
Made Chunks 16x256x16  
Increased Performance

## 02 July 2025
Added Trees  
Added Water  
Fixed Bugs  
Improved Performance  
Water Waves  
New Terrain Generation  
Moved Rendering Data Loader To Sub _GL, for faster loading  
Added Clouds  

## 03 July 2025
Clouds now regenerate, (buggy)  
