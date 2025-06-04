# Fonts Directory

This directory contains font files used by the GJTV application.

## Font Loading Solution ✅

The application now successfully loads **Cascadia Code** font using `bevy_rich_text3d`. 

### Current Working Setup:
- **Font File**: `CaskaydiaCoveNerdFont-Regular.ttf` (actually Cascadia Code)
- **Font Family**: "Cascadia Code"
- **Font Path**: `fonts/CaskaydiaCoveNerdFont-Regular.ttf`
- **Loading Method**: File path reference in `Text3dStyling`

## How Font Loading Works

1. **LoadFonts Resource**: Loads font files specified in `main.rs`
2. **Text3dStyling**: References fonts by file path (not family name)
3. **bevy_rich_text3d**: Renders text using the loaded font atlas

## Auto Download

Run the download script to get the correct font:
```bash
./download_fonts.sh
```

This downloads Microsoft Cascadia Code and renames it for consistency.

## Manual Download

### Cascadia Code (Current Working Font)
1. Visit: https://github.com/microsoft/cascadia-code/releases
2. Download `CascadiaCode-2404.23.zip`
3. Extract `ttf/CascadiaCode.ttf`
4. Rename to `CaskaydiaCoveNerdFont-Regular.ttf`

### Fira Sans (Alternative)
1. Visit: https://fonts.google.com/specimen/Fira+Sans
2. Download and extract `FiraSans-Bold.ttf`

## Font Configuration

In `main.rs`:
```rust
.insert_resource(LoadFonts {
    font_paths: vec![
        "fonts/CaskaydiaCoveNerdFont-Regular.ttf".to_string(),
        "fonts/FiraSans-Bold.ttf".to_string(),
    ],
    // ...
})
```

In `layout.rs`:
```rust
let font_arc = std::sync::Arc::from("fonts/CaskaydiaCoveNerdFont-Regular.ttf");
```

## Current Status

- [x] CaskaydiaCoveNerdFont-Regular.ttf (Cascadia Code)
- [x] Font loading verified and working
- [ ] FiraSans-Bold.ttf (optional)

## Troubleshooting

If font doesn't load:
1. Check file exists: `ls -la assets/fonts/`
2. Verify file format: `file assets/fonts/CaskaydiaCoveNerdFont-Regular.ttf`
3. Check debug output when running app
4. Ensure path matches in `LoadFonts` and `Text3dStyling`

## Notes

- ✅ Font loading works with file paths in `bevy_rich_text3d`
- ✅ Application runs successfully with Cascadia Code
- ⚠️ Font family names don't work directly in `Text3dStyling`
- 💡 Use relative paths starting with "fonts/" in the code