# Asset workflow

Use Anchorpoint with this project root as the workspace, connected to the same GitHub repository as the Godot project. Install and enable Git LFS before the first asset commit; `.gitattributes` already declares the large binary formats.

## Where each file belongs

| Asset | Location |
| --- | --- |
| Editable Aseprite files | `assets/source/art/aseprite/<asset-name>/` |
| Editable raster/vector art | `assets/source/art/raster/` or `assets/source/art/vector/` |
| Sound effects | `assets/source/audio/sfx/` |
| Music and stems | `assets/source/audio/music/` |
| Font files and licence | `assets/source/fonts/<font-name>/` |
| Exported/baked files that the game must use | `assets/derived/` |
| Downloaded packs and their licence/readme | `assets/third_party/<pack-name>/` |
| Generated editable actor scene/resources | `actors/<category>/<actor-id>/` |
| Generic Godot data | `resources/` |

Keep an asset's licence next to the asset or pack. Do not put editable source files in `resources/` or generated Godot resources in `assets/source/`.

## Collaboration rules

- Artists work from `assets/source/`; use Anchorpoint locking before editing an Aseprite, audio, or font file.
- Commit source assets and the required derived/exported outputs together when teammates need to run the project without the authoring software.
- Do not commit `.godot/`; Godot recreates it. Do commit project files, `.import` metadata, and Godot resources/scenes.
- Actor Pipeline output is ordinary editable Godot content. Generate it under `actors/`, then edit the scene and resources normally.
