# Changelog

## 0.2.0 (2026-04-21)

### Custom signatures

- Define your own MIME types via `use MagicBytes.DefineSignatures` and wire
  them in with `config :magic_bytes, extra_signatures: MyModule`
- `defsignature/2` for prefix-based signatures (offset 0)
- `defsignature_at/3` for offset-based signatures (magic bytes at any byte offset)
- `guards: true` option generates guard macros on the custom module
  (e.g. `MyModule.is_application_x_cld/1`, works for both prefix and offset signatures)
- Custom signatures are checked before built-ins; unmatched bytes fall through
  to built-in detection

### Configuration

- `config :magic_bytes, read_bytes: N` — cap the number of bytes read from
  input; defaults to the minimum required by the built-in signatures.
  Set explicitly when using offset-based custom signatures.
- `config :magic_bytes, only: [...]` — restrict detection to a specific set
  of MIME types; others return `{:error, :unknown}`
- `config :magic_bytes, exclude: [...]` — suppress specific MIME types

### New built-in signatures

- `image/jp2` (JPEG 2000)
- `image/jxl` (JPEG XL — bare codestream and ISO BMFF container)
- `image/flif`
- `application/x-lz4`
- `application/vnd.apache.parquet`
- `application/vnd.apache.arrow.file`
- `application/vnd.android.dex`

## 0.1.0 (2026-04-09)

Initial release.

- `MagicBytes.from_path/1`, `from_binary/1`, `from_stream/1` for MIME detection
- Guard macros generated for all prefix-based signatures (`is_image_jpeg/1`, `is_application_pdf/1`, etc.)
- Support for 40+ MIME types across images, audio, video, documents, archives, executables, fonts, and databases
