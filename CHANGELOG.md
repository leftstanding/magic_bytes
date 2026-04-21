# Changelog

## 0.2.0 (2026-04-20)

- Custom file signatures: define your own MIME types via `use MagicBytes.DefineSignatures`
  and configure them with `config :magic_bytes, extra_signatures: MyModule`
- `guards: true` option on `use MagicBytes.DefineSignatures` generates guard macros
  on the custom module (e.g. `MyModule.is_application_x_cld/1`)
- Custom signatures are checked before built-ins; unknown bytes fall through to built-in detection

## 0.1.0 (2026-04-09)

Initial release.

- `MagicBytes.from_path/1`, `from_binary/1`, `from_stream/1` for MIME detection
- Guard macros generated for all prefix-based signatures (`is_image_jpeg/1`, `is_application_pdf/1`, etc.)
- Support for 40+ MIME types across images, audio, video, documents, archives, executables, fonts, and databases
