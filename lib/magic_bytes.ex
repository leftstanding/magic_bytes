defmodule MagicBytes do
  @moduledoc """
  Detect MIME types from binary content using magic byte signatures.

  Only the required bytes to discern the signature are used, seperating performance
  from file size. The default size is 16 bytes which satisfies the majority of file types.
  The first `#{Application.compile_env(:magic_bytes, :read_bytes, 16)}` bytes of input are
  examined (configurable — see below).

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

  ## Custom signatures

  Define a module with `use MagicBytes.DefineSignatures`, configure it once,
  and all `from_*` functions will check your signatures first, falling back to
  the built-ins automatically.

      defmodule MyApp.Signatures do
        use MagicBytes.DefineSignatures, guards: true
        defsignature("application/x-cld", <<0xCA, 0xFE, 0xD0, 0x0D>>)
        defsignature_at("application/x-tar", 257, "ustar")
      end

      # config/config.exs
      config :magic_bytes,
        extra_signatures: MyApp.Signatures,
        read_bytes: 262  # must cover the largest offset + size in your signatures

  Passing `guards: true` generates guard macros on your module
  (e.g. `MyApp.Signatures.is_application_x_cld/1`, `MyApp.Signatures.is_application_x_tar/1`)
  that can be used in `when` clauses after `require MyApp.Signatures`.

  ## Configuration

  Set in `config/config.exs` (values are resolved at compile time):

  | Key                | Type          | Default | Description |
  |--------------------|---------------|---------|-------------|
  | `:extra_signatures`| module        | `nil`   | Module with additional signatures |
  | `:read_bytes`      | pos_integer   | auto    | Bytes read from input; defaults to the minimum required by the built-in signatures. Set explicitly when using offset-based custom signatures. |
  | `:only`            | list(String)  | `nil`   | When set, only these MIME types are returned; others become `{:error, :unknown}` |
  | `:exclude`         | list(String)  | `[]`    | MIME types to suppress; ignored when `:only` is set |

  ## Supported formats

  | Category    | MIME types |
  |-------------|------------|
  | Images      | `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `image/bmp`,
  |               `image/tiff`, `image/x-icon`, `image/vnd.adobe.photoshop`,
  |               `image/heic`, `image/avif`, `image/jp2`, `image/jxl`, `image/flif` |
  | Audio       | `audio/mpeg`, `audio/flac`, `audio/ogg`, `audio/wav`, `audio/aiff`, `audio/mp4` |
  | Video       | `video/mp4`, `video/quicktime`, `video/x-matroska`, `video/x-flv`, `video/x-msvideo` |
  | Documents   | `application/pdf`, `application/zip`, `application/x-cfb`, `application/rtf` |
  | Archives    | `application/x-rar-compressed`, `application/x-7z-compressed`, `application/gzip`,
  |             | `application/x-bzip2`, `application/x-xz`, `application/zstd`, `application/x-lz4` |
  | Data        | `application/vnd.apache.parquet`, `application/vnd.apache.arrow.file` |
  | Executables | `application/x-elf`, `application/x-msdownload`, `application/x-mach-binary`,
  |             | `application/wasm`, `application/vnd.android.dex` |
  | Fonts       | `font/woff`, `font/woff2`, `font/otf`, `font/ttf` |
  | Database    | `application/x-sqlite3` |
  """

  require MagicBytes.DefineSignatures
  require MagicBytes.FileSignatures

  alias MagicBytes.FileSignatures

  @type mime_type :: String.t()
  @type error :: {:error, :unreadable | :unknown}

  @extra Application.compile_env(:magic_bytes, :extra_signatures, nil)
  @only Application.compile_env(:magic_bytes, :only, nil)
  @exclude Application.compile_env(:magic_bytes, :exclude, [])
  @read_bytes Application.compile_env(:magic_bytes, :read_bytes, FileSignatures.required_bytes())

  MagicBytes.DefineSignatures.generate_guards(MagicBytes.FileSignatures)

  @doc """
  Detects the MIME type of the file at `path` by reading its leading bytes.

  Returns `{:error, :unreadable}` if the file cannot be opened.

  ## Examples

      iex> MagicBytes.from_path("test/fixtures/fixture.jpg")
      {:ok, "image/jpeg"}

      iex> MagicBytes.from_path("test/fixtures/fixture.png")
      {:ok, "image/png"}

      iex> MagicBytes.from_path("test/fixtures/fixture.pdf")
      {:ok, "application/pdf"}

      iex> MagicBytes.from_path("/nonexistent/file.jpg")
      {:error, :unreadable}
  """
  @spec from_path(Path.t()) :: {:ok, mime_type()} | error()
  def from_path(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, file} ->
        result = file |> IO.binread(@read_bytes) |> do_match()
        File.close(file)
        result

      {:error, _} ->
        {:error, :unreadable}
    end
  end

  @doc """
  Detects the MIME type from a binary.

  Only the leading bytes are examined; passing the full file content is
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
  def from_binary(data) when is_binary(data), do: do_match(data)

  @doc """
  Detects the MIME type from a stream of binaries.

  Chunks are accumulated until enough bytes are available, then detection
  runs on the combined header. The stream is not fully consumed.

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
      if byte_size(combined) >= @read_bytes, do: {:halt, combined}, else: {:cont, combined}
    end)
    |> do_match()
  end

  defp do_match(<<>>), do: {:error, :unreadable}

  if @extra do
    defp do_match(data) do
      case @extra.match(data) do
        {:error, :unknown} -> data |> FileSignatures.match() |> filter_match()
        result -> filter_match(result)
      end
    end
  else
    defp do_match(data), do: data |> FileSignatures.match() |> filter_match()
  end

  if @only do
    defp filter_match({:ok, mime}) when mime in @only, do: {:ok, mime}
    defp filter_match({:ok, _mime}), do: {:error, :unknown}
    defp filter_match(result), do: result
  else
    if @exclude != [] do
      defp filter_match({:ok, mime}) when mime in @exclude, do: {:error, :unknown}
    end

    defp filter_match(result), do: result
  end
end
