defmodule MagicBytes.FileSignatures do
  use MagicBytes.DefineSignatures

  # Images
  defsignature("image/jpeg", <<0xFF, 0xD8, 0xFF>>)
  defsignature("image/png", <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>)
  defsignature("image/gif", <<"GIF8">>)
  defsignature("image/bmp", <<"BM">>)
  defsignature("image/tiff", <<"II", 42, 0>>)
  defsignature("image/tiff", <<"MM", 0, 42>>)
  defsignature("image/x-icon", <<0, 0, 1, 0>>)
  defsignature("image/vnd.adobe.photoshop", <<"8BPS">>)

  # Audio/Video
  defsignature("video/x-matroska", <<0x1A, 0x45, 0xDF, 0xA3>>)
  defsignature("video/x-flv", <<"FLV">>)
  defsignature("audio/mpeg", <<"ID3">>)
  defsignature("audio/mpeg", <<0xFF, 0xFB>>)
  defsignature("audio/mpeg", <<0xFF, 0xF3>>)
  defsignature("audio/mpeg", <<0xFF, 0xF2>>)
  defsignature("audio/flac", <<"fLaC">>)
  defsignature("audio/ogg", <<"OggS">>)

  # Documents & Archives
  defsignature("application/pdf", <<"%PDF">>)
  defsignature("application/zip", <<"PK", 3, 4>>)
  defsignature("application/zip", <<"PK", 5, 6>>)
  defsignature("application/zip", <<"PK", 7, 8>>)
  defsignature("application/x-cfb", <<0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1>>)
  defsignature("application/rtf", <<"{\\rtf">>)
  defsignature("application/x-rar-compressed", <<"Rar!", 0x1A, 0x07, 0x01, 0x00>>)
  defsignature("application/x-rar-compressed", <<"Rar!", 0x1A, 0x07, 0x00>>)
  defsignature("application/x-7z-compressed", <<"7z", 0xBC, 0xAF, 0x27, 0x1C>>)
  defsignature("application/gzip", <<0x1F, 0x8B>>)
  defsignature("application/x-bzip2", <<"BZh">>)
  defsignature("application/x-xz", <<0xFD, "7zXZ", 0x00>>)
  defsignature("application/zstd", <<0x28, 0xB5, 0x2F, 0xFD>>)

  # Executables & Bytecode
  defsignature("application/x-elf", <<0x7F, "ELF">>)
  defsignature("application/x-msdownload", <<"MZ">>)
  defsignature("application/x-mach-binary", <<0xFE, 0xED, 0xFA, 0xCE>>)
  defsignature("application/x-mach-binary", <<0xFE, 0xED, 0xFA, 0xCF>>)
  defsignature("application/x-mach-binary", <<0xCE, 0xFA, 0xED, 0xFE>>)
  defsignature("application/x-mach-binary", <<0xCF, 0xFA, 0xED, 0xFE>>)
  defsignature("application/x-mach-binary", <<0xCA, 0xFE, 0xBA, 0xBE>>)
  defsignature("application/wasm", <<0x00, 0x61, 0x73, 0x6D>>)

  # Fonts
  defsignature("font/woff", <<"wOFF">>)
  defsignature("font/woff2", <<"wOF2">>)
  defsignature("font/otf", <<"OTTO">>)
  defsignature("font/ttf", <<0x00, 0x01, 0x00, 0x00, 0x00>>)

  # Database
  defsignature("application/x-sqlite3", <<"SQLite format 3", 0x00>>)

  # RIFF container: 4-byte subtype at offset 8 distinguishes format
  def match(<<"RIFF", _::32, "WEBP", _::binary>>), do: {:ok, "image/webp"}
  def match(<<"RIFF", _::32, "WAVE", _::binary>>), do: {:ok, "audio/wav"}
  def match(<<"RIFF", _::32, "AVI ", _::binary>>), do: {:ok, "video/x-msvideo"}

  # IFF container (AIFF and AIFF-C)
  def match(<<"FORM", _::32, "AIFF", _::binary>>), do: {:ok, "audio/aiff"}
  def match(<<"FORM", _::32, "AIFC", _::binary>>), do: {:ok, "audio/aiff"}

  # ISO Base Media: ftyp box at offset 4, brand at offset 8 (specific before generic)
  def match(<<_::32, "ftyp", "heic", _::binary>>), do: {:ok, "image/heic"}
  def match(<<_::32, "ftyp", "heix", _::binary>>), do: {:ok, "image/heic"}
  def match(<<_::32, "ftyp", "avif", _::binary>>), do: {:ok, "image/avif"}
  def match(<<_::32, "ftyp", "M4A ", _::binary>>), do: {:ok, "audio/mp4"}
  def match(<<_::32, "ftyp", "M4V ", _::binary>>), do: {:ok, "video/mp4"}
  def match(<<_::32, "ftyp", "qt  ", _::binary>>), do: {:ok, "video/quicktime"}
  def match(<<_::32, "ftyp", _::binary>>), do: {:ok, "video/mp4"}
end
