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

  test "image/jxl bare codestream" do
    assert MagicBytes.from_binary(<<0xFF, 0x0A, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>) ==
             {:ok, "image/jxl"}
  end

  test "application/vnd.android.dex" do
    assert MagicBytes.from_binary(<<"dex\n035\0", 0, 0, 0, 0, 0, 0, 0, 0>>) ==
             {:ok, "application/vnd.android.dex"}
  end

  describe "DefineSignatures" do
    defmodule LocalSigs do
      use MagicBytes.DefineSignatures
      defsignature("application/x-local", <<0xAB, 0xCD, 0xEF, 0x00>>)
    end

    test "match/1 returns ok for a defined prefix" do
      assert LocalSigs.match(<<0xAB, 0xCD, 0xEF, 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>) ==
               {:ok, "application/x-local"}
    end

    test "match/1 returns unknown for an unregistered prefix" do
      assert LocalSigs.match(<<0xFF, 0xD8, 0xFF, 0xE0>>) == {:error, :unknown}
    end

    test "signatures/0 lists all defined signatures" do
      assert LocalSigs.signatures() == [{"application/x-local", <<0xAB, 0xCD, 0xEF, 0x00>>}]
    end

    test "required_bytes/0 returns the max bytes needed" do
      assert LocalSigs.required_bytes() == 4
    end
  end

  describe "defsignature_at" do
    defmodule OffsetSigs do
      use MagicBytes.DefineSignatures, guards: true
      defsignature_at("application/x-offset-test", 4, <<0xCA, 0xFE>>)
    end

    @offset_data <<0x00, 0x00, 0x00, 0x00, 0xCA, 0xFE, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                   0x00, 0x00, 0x00>>

    test "match/1 returns ok when bytes at offset match" do
      assert OffsetSigs.match(@offset_data) == {:ok, "application/x-offset-test"}
    end

    test "match/1 returns unknown when bytes at offset do not match" do
      assert OffsetSigs.match(
               <<0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
             ) ==
               {:error, :unknown}
    end

    test "match/1 returns unknown when input is shorter than required" do
      assert OffsetSigs.match(<<0x00, 0x00, 0x00, 0x00, 0xCA>>) == {:error, :unknown}
    end

    test "required_bytes/0 returns offset + signature length" do
      assert OffsetSigs.required_bytes() == 6
    end

    test "offset_signatures/0 lists defined offset signatures" do
      assert OffsetSigs.offset_signatures() == [{"application/x-offset-test", 4, <<0xCA, 0xFE>>}]
    end

    test "guard is generated for offset signature" do
      require MagicBytesTest.OffsetSigs
      assert OffsetSigs.is_application_x_offset_test(@offset_data)
      refute OffsetSigs.is_application_x_offset_test(<<0xFF, 0xD8, 0xFF, 0xE0>>)
    end
  end

  # MagicBytes.Test.ExtraSignatures is configured via config/test.exs:
  #   config :magic_bytes, extra_signatures: MagicBytes.Test.ExtraSignatures
  # It registers:
  #   defsignature("application/x-custom", <<0xDE, 0xAD, 0xC0, 0xDE>>)
  #   defsignature_at("application/x-custom-offset", 4, <<0xBE, 0xEF>>)
  describe "extra_signatures config" do
    @custom <<0xDE, 0xAD, 0xC0, 0xDE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    @custom_offset <<0x00, 0x00, 0x00, 0x00, 0xBE, 0xEF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

    test "from_binary resolves custom prefix mime" do
      assert MagicBytes.from_binary(@custom) == {:ok, "application/x-custom"}
    end

    test "from_binary resolves custom offset mime" do
      assert MagicBytes.from_binary(@custom_offset) == {:ok, "application/x-custom-offset"}
    end

    test "from_stream resolves custom prefix mime" do
      assert MagicBytes.from_stream([@custom]) == {:ok, "application/x-custom"}
    end

    test "from_stream resolves custom offset mime" do
      assert MagicBytes.from_stream([@custom_offset]) == {:ok, "application/x-custom-offset"}
    end

    test "built-in signatures still resolve alongside custom" do
      assert MagicBytes.from_binary(<<0xFF, 0xD8, 0xFF, 0xE0>>) == {:ok, "image/jpeg"}
    end

    test "unknown bytes still return error" do
      assert MagicBytes.from_binary(<<0x00, 0x00, 0x00, 0x00>>) == {:error, :unknown}
    end

    test "prefix guard is generated on the custom signatures module" do
      require MagicBytes.Test.ExtraSignatures, as: ExtraSigs
      assert ExtraSigs.is_application_x_custom(@custom)
      refute ExtraSigs.is_application_x_custom(<<0xFF, 0xD8, 0xFF, 0xE0>>)
    end

    test "offset guard is generated on the custom signatures module" do
      require MagicBytes.Test.ExtraSignatures, as: ExtraSigs
      assert ExtraSigs.is_application_x_custom_offset(@custom_offset)
      refute ExtraSigs.is_application_x_custom_offset(@custom)
    end
  end
end
