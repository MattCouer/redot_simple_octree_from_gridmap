# redot_simple_octree_from_gridmap
generates octree (raster) from the used cells of GridMap in free and open source Redot 4.3

Get Redot from here:
https://github.com/Redot-Engine/redot-engine

How to use:

Inside Redot project, create scene.
Add GridMap node to scene.
Attach octree_from_gridmap script to any node of the scene.
Assign GridMap to Grid Map property of script.
Adjust settings as desired.

Access octree from the octree_from_gridmap.raster property.
Access octree class from octree_from_gridmap.octree.

![GridMap_Octree_Gif](https://github.com/user-attachments/assets/bf9a139b-808e-49d0-8daa-d228648cabc1)
