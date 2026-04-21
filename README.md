# MagicBytes

[![CI](https://github.com/leftstanding/magic_bytes/actions/workflows/ci.yml/badge.svg)](https://github.com/leftstanding/magic_bytes/actions/workflows/ci.yml)
[![Hex Version](https://img.shields.io/hexpm/v/magic_bytes.svg)](https://hex.pm/packages/magic_bytes)
[![Hex Downloads](https://img.shields.io/hexpm/dt/magic_bytes.svg)](https://hex.pm/packages/magic_bytes)
[![License](https://img.shields.io/hexpm/l/magic_bytes.svg)](https://github.com/leftstanding/magic_bytes/blob/main/LICENSE)

Detects MIME types from binary content using magic byte signatures. Only the
first 16 bytes of input are required, making resolution fast regardless of
file size.

## Installation

```elixir
def deps do
  [
    {:magic_bytes, "~> 0.1.0"}
  ]
end
```

## Usage

### From a file path

```elixir
MagicBytes.from_path("image.png")
#=> {:ok, "image/png"}

MagicBytes.from_path("archive.tar.gz")
#=> {:ok, "application/gzip"}

MagicBytes.from_path("/nonexistent/file")
#=> {:error, :unreadable}
```

### From a binary

Useful when bytes are already in memory — e.g. an upload buffer or a
database blob. Only the leading bytes matter; passing the full content works
but is not required.

```elixir
MagicBytes.from_binary(<<0xFF, 0xD8, 0xFF, 0xE0>>)
#=> {:ok, "image/jpeg"}

MagicBytes.from_binary(file_contents)
#=> {:ok, "application/pdf"}

MagicBytes.from_binary(<<0x00, 0x00, 0x00, 0x00>>)
#=> {:error, :unknown}
```

### From a stream

Chunks are accumulated until the required 16 bytes are accumulated and run.
The stream is not fully consumed.

```elixir
File.stream!("video.mkv", 1024)
|> MagicBytes.from_stream()
#=> {:ok, "video/x-matroska"}
```

### Guards

For prefix-based signatures a corresponding guard macro is generated and
re-exported from `MagicBytes`. Guard names follow the pattern
`is_<mime_type>` with `/` and `-` replaced by `_`.

```elixir
require MagicBytes

def process(bin) when MagicBytes.is_image_jpeg(bin), do: ...
def process(bin) when MagicBytes.is_image_png(bin), do: ...
def process(bin) when MagicBytes.is_application_pdf(bin), do: ...
def process(_bin), do: {:error, :unsupported}
```

Guards also work as boolean expressions outside `when` clauses:

```elixir
require MagicBytes
MagicBytes.is_application_gzip(data)  #=> true | false
```

Guards are not generated for container-format signatures where the
distinguishing bytes appear at a non-zero offset (WebP, WAV, AVI, AIFF,
MP4, HEIC, AVIF, QuickTime). Use `from_binary/1` for those formats.

### Custom signatures

Define a module with `use MagicBytes.DefineSignatures`, configure it once,
and all `from_*` functions will check your signatures first, falling back to
the built-ins automatically.

```elixir
defmodule MyApp.Signatures do
  use MagicBytes.DefineSignatures, guards: true
  defsignature("application/x-cld", <<0xCA, 0xFE, 0xD0, 0x0D>>)
end
```

```elixir
# config/config.exs
config :magic_bytes, extra_signatures: MyApp.Signatures
```

```elixir
MagicBytes.from_binary(<<0xCA, 0xFE, 0xD0, 0x0D, ...>>)
#=> {:ok, "application/x-cld"}
```

Passing `guards: true` generates guard macros on your module. Because guards
must be resolved at compile time and your module compiles after the
`magic_bytes` dependency, they live on your module rather than on `MagicBytes`:

```elixir
require MyApp.Signatures

def process(bin) when MyApp.Signatures.is_application_x_cld(bin), do: ...
```

## Supported formats

| Category    | MIME types                                                                                          |
|-------------|-----------------------------------------------------------------------------------------------------|
| Images      | `image/jpeg` `image/png` `image/gif` `image/webp` `image/bmp` `image/tiff` `image/x-icon` `image/vnd.adobe.photoshop` `image/heic` `image/avif` |
| Audio       | `audio/mpeg` `audio/flac` `audio/ogg` `audio/wav` `audio/aiff` `audio/mp4`                        |
| Video       | `video/mp4` `video/quicktime` `video/x-matroska` `video/x-flv` `video/x-msvideo`                  |
| Documents   | `application/pdf` `application/zip` `application/x-cfb` `application/rtf`                          |
| Archives    | `application/x-rar-compressed` `application/x-7z-compressed` `application/gzip` `application/x-bzip2` `application/x-xz` `application/zstd` |
| Executables | `application/x-elf` `application/x-msdownload` `application/x-mach-binary` `application/wasm`     |
| Fonts       | `font/woff` `font/woff2` `font/otf` `font/ttf`                                                     |
| Database    | `application/x-sqlite3`                                                                             |
