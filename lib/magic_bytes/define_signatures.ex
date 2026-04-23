defmodule MagicBytes.DefineSignatures do
  @moduledoc false

  defmacro __using__(opts) do
    generate_guards = Keyword.get(opts, :guards, false)

    quote do
      Module.register_attribute(__MODULE__, :signatures, accumulate: true)
      Module.register_attribute(__MODULE__, :offset_signatures, accumulate: true)
      @magic_bytes_generate_guards unquote(generate_guards)
      import MagicBytes.DefineSignatures, only: [defsignature: 2, defsignature_at: 3]

      @before_compile MagicBytes.DefineSignatures
    end
  end

  defmacro defsignature(mime, prefix),
    do: quote(do: @signatures({unquote(mime), unquote(prefix)}))

  defmacro defsignature_at(mime, offset, bytes),
    do: quote(do: @offset_signatures({unquote(mime), unquote(offset), unquote(bytes)}))

  defmacro __before_compile__(env) do
    signatures = Module.get_attribute(env.module, :signatures)
    offset_signatures = Module.get_attribute(env.module, :offset_signatures)

    uniq_prefix = Enum.uniq_by(signatures, fn {mime, _} -> mime_to_guard_name(mime) end)
    uniq_offset = Enum.uniq_by(offset_signatures, fn {mime, _, _} -> mime_to_guard_name(mime) end)

    prefix_max =
      signatures |> Enum.map(fn {_, p} -> byte_size(p) end) |> Enum.max(fn -> 0 end)

    offset_max =
      offset_signatures
      |> Enum.map(fn {_, o, b} -> o + byte_size(b) end)
      |> Enum.max(fn -> 0 end)

    required_bytes = max(prefix_max, offset_max)

    prefix_match_clauses =
      for {mime, prefix} <- signatures do
        quote do
          def match(<<unquote(prefix)::binary, _::binary>>), do: {:ok, unquote(mime)}
        end
      end

    offset_match_clauses =
      for {mime, offset, bytes} <- offset_signatures do
        size = byte_size(bytes)

        quote do
          def match(bin)
              when byte_size(bin) >= unquote(offset) + unquote(size) and
                     binary_part(bin, unquote(offset), unquote(size)) == unquote(bytes),
              do: {:ok, unquote(mime)}
        end
      end

    guard_clauses =
      case Module.get_attribute(env.module, :magic_bytes_generate_guards) do
        true ->
          prefix_guards = for {mime, prefix} <- uniq_prefix, do: build_guard(mime, prefix)
          offset_guards = for {mime, o, b} <- uniq_offset, do: build_offset_guard(mime, o, b)
          prefix_guards ++ offset_guards

        _ ->
          []
      end

    quote do
      def signatures, do: unquote(Macro.escape(signatures))
      def offset_signatures, do: unquote(Macro.escape(offset_signatures))
      def required_bytes, do: unquote(required_bytes)

      unquote_splicing(guard_clauses)
      unquote_splicing(prefix_match_clauses)
      unquote_splicing(offset_match_clauses)

      def match(_), do: {:error, :unknown}
    end
  end

  defmacro generate_guards(module) do
    module = Macro.expand(module, __CALLER__)

    prefix_guards =
      module.signatures()
      |> Enum.uniq_by(fn {mime, _} -> mime_to_guard_name(mime) end)
      |> Enum.map(fn {mime, prefix} -> build_guard(mime, prefix) end)

    offset_guards =
      module.offset_signatures()
      |> Enum.uniq_by(fn {mime, _, _} -> mime_to_guard_name(mime) end)
      |> Enum.map(fn {mime, offset, bytes} -> build_offset_guard(mime, offset, bytes) end)

    quote do
      (unquote_splicing(prefix_guards ++ offset_guards))
    end
  end

  defp build_guard(mime, prefix) do
    guard_name = mime_to_guard_name(mime)
    prefix_size = byte_size(prefix)

    bin = Macro.var(:bin, __MODULE__)
    head = {guard_name, [], [bin]}

    quote do
      defguard unquote(head)
               when is_binary(unquote(bin)) and
                      byte_size(unquote(bin)) >= unquote(prefix_size) and
                      binary_part(unquote(bin), 0, unquote(prefix_size)) == unquote(prefix)
    end
  end

  defp build_offset_guard(mime, offset, bytes) do
    guard_name = mime_to_guard_name(mime)
    size = byte_size(bytes)

    bin = Macro.var(:bin, __MODULE__)
    head = {guard_name, [], [bin]}

    quote do
      defguard unquote(head)
               when is_binary(unquote(bin)) and
                      byte_size(unquote(bin)) >= unquote(offset) + unquote(size) and
                      binary_part(unquote(bin), unquote(offset), unquote(size)) == unquote(bytes)
    end
  end

  defp mime_to_guard_name(mime) do
    mime
    |> String.replace(~r/[^a-zA-Z0-9]+/, "_")
    |> String.downcase()
    |> then(&:"is_#{&1}")
  end
end
