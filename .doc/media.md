# macOS Media (`modules/macos/media/`)

Bevat audio-, video-, afbeelding- en e-book-tooling:
- `audiomaster` (`AUDIO/`): Audio-conversie, AAC-fixes en MP3-tagging.
- `videomaster` (`VIDEO/`): Video-conversie, 16:9-aanpassing, A/V-combinatie.
- `imagemaster`: Afbeeldingen batchgewijs verwerken en metadata beheren.
- `karaokemaster` (`KARAOKE/`): CDG-conversie, artiest-consolidatie en muziekorganisatie.
- `rename_ebooks`: E-books hernoemen op basis van metadata.

### Vereiste Dependencies
`ffmpeg`, `exiftool`, `magick`, `yt-dlp`, `mutagen`, `pillow`, `pypdf`

### Gebruik
```bash
./master media audiomaster
./master media videomaster
./master media imagemaster
```
