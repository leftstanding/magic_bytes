defmodule MagicBytesTest do
  use ExUnit.Case, async: true
  doctest MagicBytes

  alias MagicBytes.Test.Fixtures

  for {filename, expected_mime} <- Fixtures.all() do
    @filename filename
    @expected expected_mime
    test "from_path detects #{@expected} from #{@filename}" do
      assert MagicBytes.from_path(Fixtures.path(@filename)) == {:ok, @expected}
    end

    test "from_stream detects #{@expected} from #{@filename}" do
      stream = File.stream!(Fixtures.path(@filename), 36)
      assert MagicBytes.from_stream(stream) == {:ok, @expected}
    end

    test "from_binary detects #{@expected} from #{@filename}" do
      header = File.open!(Fixtures.path(@filename), [:read, :binary], &IO.binread(&1, 36))
      assert MagicBytes.from_binary(header) == {:ok, @expected}
    end
  end

  test "guards work as boolean expressions" do
    require MagicBytes
    assert MagicBytes.is_image_jpeg(<<0xFF, 0xD8, 0xFF, 0xE0>>)
    refute MagicBytes.is_image_jpeg(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>)
  end
end
