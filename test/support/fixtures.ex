defmodule MagicBytes.Test.Fixtures do
  @moduledoc false

  @base_url "https://raw.githubusercontent.com/sindresorhus/file-type/main/fixture"
  @dir Path.join(__DIR__, "../fixtures")

  # {filename, expected_mime}
  @files [
    # Images
    {"fixture.jpg", "image/jpeg"},
    {"fixture.png", "image/png"},
    {"fixture.gif", "image/gif"},
    {"fixture.webp", "image/webp"},
    {"fixture.bmp", "image/bmp"},
    {"fixture-little-endian.tif", "image/tiff"},
    {"fixture.ico", "image/x-icon"},
    {"fixture.psd", "image/vnd.adobe.photoshop"},
    {"fixture-heic.heic", "image/heic"},
    {"fixture-yuv420-8bit.avif", "image/avif"},
    # Audio/Video
    {"fixture.wav", "audio/wav"},
    {"fixture.avi", "video/x-msvideo"},
    {"fixture.m4a", "audio/mp4"},
    {"fixture-isom.mp4", "video/mp4"},
    {"fixture.mkv", "video/x-matroska"},
    {"fixture.flv", "video/x-flv"},
    {"fixture.mp3", "audio/mpeg"},
    {"fixture.flac", "audio/flac"},
    {"fixture.ogg", "audio/ogg"},
    {"fixture.aif", "audio/aiff"},
    # Documents & Archives
    {"fixture.pdf", "application/pdf"},
    {"fixture.zip", "application/zip"},
    {"fixture.doc.cfb", "application/x-cfb"},
    {"fixture.rtf", "application/rtf"},
    {"fixture.rar", "application/x-rar-compressed"},
    {"fixture.7z", "application/x-7z-compressed"},
    {"fixture.gz", "application/gzip"},
    {"fixture.bz2", "application/x-bzip2"},
    {"fixture.tar.xz", "application/x-xz"},
    {"fixture.tar.zst", "application/zstd"},
    # Executables & Bytecode
    {"fixture.elf", "application/x-elf"},
    {"fixture.exe", "application/x-msdownload"},
    {"fixture.wasm", "application/wasm"},
    # Fonts
    {"fixture.woff", "font/woff"},
    {"fixture.woff2", "font/woff2"},
    {"fixture.otf", "font/otf"},
    {"fixture.ttf", "font/ttf"},
    # Database
    {"fixture.sqlite", "application/x-sqlite3"}
  ]

  def all, do: @files
  def path(filename), do: Path.join(@dir, filename)

  def ensure_downloaded! do
    File.mkdir_p!(@dir)
    Enum.each(@files, &download_if_missing/1)
  end

  defp download_if_missing({filename, _}) do
    dest = path(filename)

    unless File.exists?(dest) do
      url = "#{@base_url}/#{filename}"

      case System.cmd("curl", ["-fsSL", "-o", dest, url], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, code} -> raise "Failed to download #{filename} (exit #{code}): #{output}"
      end
    end
  end
end
