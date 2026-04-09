defmodule MagicBytes do
  @moduledoc """
  Detect MIME types from binary content using magic byte signatures.

  Only the first 16 bytes of input are examined. Three entry points cover
  the common cases — file path, raw binary, and streaming data:

      iex> MagicBytes.from_binary(<<0xFF, 0xD8, 0xFF, 0xE0>>)
      {:ok, "image/jpeg"}

      iex> MagicBytes.from_binary(<<0x00, 0x00, 0x00, 0x00>>)
      {:error, :unknown}

  ## Guards

  For prefix-based signatures a corresponding guard macro is generated,
  named `is_<mime_with_slashes_and_hyphens_as_underscores>`. These expand
  to pure boolean expressions and can be used in `when` clauses or regular
  code after `require MagicBytes`:

      iex> require MagicBytes
      iex> MagicBytes.is_image_jpeg(<<0xFF, 0xD8, 0xFF, 0xE0>>)
      true

      iex> require MagicBytes
      iex> MagicBytes.is_application_pdf(<<?%, ?P, ?D, ?F, ?-, ?1, ?., ?7>>)
      true

  Guards are not generated for container-format signatures that require
  inspecting bytes beyond a fixed prefix (WebP, WAV, AVI, AIFF, MP4,
  HEIC, AVIF, QuickTime). Use `from_binary/1` for those.

  ## Supported formats

  | Category   | MIME types |
  |------------|------------|
  | Images     | `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `image/bmp`,
  |              `image/tiff`, `image/x-icon`, `image/vnd.adobe.photoshop`, `image/heic`, `image/avif` |
  | Audio      | `audio/mpeg`, `audio/flac`, `audio/ogg`, `audio/wav`, `audio/aiff`, `audio/mp4` |
  | Video      | `video/mp4`, `video/quicktime`, `video/x-matroska`, `video/x-flv`, `video/x-msvideo` |
  | Documents  | `application/pdf`, `application/zip`, `application/x-cfb`, `application/rtf` |
  | Archives   | `application/x-rar-compressed`, `application/x-7z-compressed`, `application/gzip`,
  |            | `application/x-bzip2`, `application/x-xz`, `application/zstd` |
  | Executable | `application/x-elf`, `application/x-msdownload`, `application/x-mach-binary`, `application/wasm` |
  | Fonts      | `font/woff`, `font/woff2`, `font/otf`, `font/ttf` |
  | Database   | `application/x-sqlite3` |
  """

  require MagicBytes.FileSignatures

  alias MagicBytes.FileSignatures

  @type mime_type :: String.t()
  @type error :: {:error, :unreadable | :unknown}

  @doc """
  Detects the MIME type of the file at `path` by reading its first 16 bytes.

  Returns `{:error, :unreadable}` if the file cannot be opened.

  ## Examples

      iex> MagicBytes.from_binary("image_file.jpg")
      iex> {:ok, "image/jpg"}

      iex> MagicBytes.from_binary("pdf_file.pdf")
      iex> {:ok, "application/pdf"}

      iex> MagicBytes.from_path("/nonexistent/file.jpg")
      {:error, :unreadable}
  """
  @spec from_path(Path.t()) :: {:ok, mime_type()} | error()
  def from_path(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, file} ->
        result = file |> IO.binread(16) |> FileSignatures.match()
        File.close(file)
        result

      {:error, _} ->
        {:error, :unreadable}
    end
  end

  @doc """
  Detects the MIME type from a binary.

  Only the first 16 bytes are examined; passing the full file content is
  fine but unnecessary.

  ## Examples

      iex> MagicBytes.from_binary(<<0xFF, 0xD8, 0xFF, 0xE0>>)
      {:ok, "image/jpeg"}

      iex> MagicBytes.from_binary(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>)
      {:ok, "image/png"}

      iex> MagicBytes.from_binary(<<?%, ?P, ?D, ?F>>)
      {:ok, "application/pdf"}

      iex> MagicBytes.from_binary(<<0x1F, 0x8B>>)
      {:ok, "application/gzip"}

      iex> MagicBytes.from_binary(<<0x00, 0x00, 0x00, 0x00>>)
      {:error, :unknown}
  """
  @spec from_binary(binary()) :: {:ok, mime_type()} | error()
  def from_binary(data) when is_binary(data), do: FileSignatures.match(data)

  @doc """
  Detects the MIME type from a stream of binaries.

  Chunks are accumulated until at least 16 bytes are available, then
  detection runs on the combined header. The stream is not fully consumed.

  Returns `{:error, :unreadable}` if the stream is empty.

  ## Examples

      iex> MagicBytes.from_stream([<<0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>])
      {:ok, "image/jpeg"}

      iex> MagicBytes.from_stream([<<0xFF, 0xD8>>, <<0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>])
      {:ok, "image/jpeg"}

      iex> MagicBytes.from_stream([])
      {:error, :unreadable}
  """
  @spec from_stream(Enumerable.t()) :: {:ok, mime_type()} | error()
  def from_stream(stream) do
    Enum.reduce_while(stream, <<>>, fn chunk, acc ->
      combined = acc <> chunk
      if byte_size(combined) >= 16, do: {:halt, combined}, else: {:cont, combined}
    end)
    |> case do
      <<>> -> {:error, :unreadable}
      data -> FileSignatures.match(data)
    end
  end

  # Generate guard_clauses.
  for {mime, prefix} <- MagicBytes.FileSignatures.signatures() |> Enum.uniq_by(&elem(&1, 0)) do
    guard_name = :"is_#{String.replace(mime, ~r/[^a-zA-Z0-9]+/, "_") |> String.downcase()}"
    prefix_size = byte_size(prefix)

    defguard unquote(guard_name)(bin)
             when is_binary(bin) and
                    byte_size(bin) >= unquote(prefix_size) and
                    binary_part(bin, 0, unquote(prefix_size)) == unquote(prefix)
  end
end
