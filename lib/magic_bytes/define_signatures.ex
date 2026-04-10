defmodule MagicBytes.DefineSignatures do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :signatures, accumulate: true)
      import MagicBytes.DefineSignatures, only: [defsignature: 2]

      @before_compile MagicBytes.DefineSignatures
    end
  end

  defmacro defsignature(mime, prefix),
    do: quote(do: @signatures({unquote(mime), unquote(prefix)}))

  defmacro __before_compile__(env) do
    signatures = env.module |> Module.get_attribute(:signatures)

    uniq = signatures |> Enum.uniq_by(fn {mime, _prefix} -> mime_to_guard_name(mime) end)

    match_clauses =
      for {mime, prefix} <- signatures do
        quote do
          def match(<<unquote(prefix)::binary, _::binary>>), do: {:ok, unquote(mime)}
        end
      end

    guard_clauses =
      case Module.get_attribute(env.module, :magic_bytes_generate_guards) do
        true ->
          for {mime, prefix} <- uniq do
            build_guard(mime, prefix)
          end

        _ ->
          []
      end

    quote do
      def signatures, do: unquote(Macro.escape(signatures))

      unquote_splicing(guard_clauses)
      unquote_splicing(match_clauses)

      def match(_), do: {:error, :unknown}
    end
  end

  defmacro generate_guards(module) do
    module = Macro.expand(module, __CALLER__)
    sigs = module.signatures()
    uniq = Enum.uniq_by(sigs, fn {mime, _prefix} -> mime_to_guard_name(mime) end)
    guard_clauses = for {mime, prefix} <- uniq, do: build_guard(mime, prefix)

    quote do
      (unquote_splicing(guard_clauses))
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

  defp mime_to_guard_name(mime) do
    mime
    |> String.replace(~r/[^a-zA-Z0-9]+/, "_")
    |> String.downcase()
    |> then(&:"is_#{&1}")
  end
end
