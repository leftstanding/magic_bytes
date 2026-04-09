defmodule MagicBytes.DefineSignatures do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      import MagicBytes.DefineSignatures, only: [defsignature: 2]
      Module.register_attribute(__MODULE__, :signatures, accumulate: true)
      @before_compile MagicBytes.DefineSignatures
    end
  end

  defmacro defsignature(mime, prefix),
    do: quote(do: @signatures({unquote(mime), unquote(prefix)}))

  defmacro __before_compile__(env) do
    signatures = env.module |> Module.get_attribute(:signatures)

    match_clauses =
      for {mime, prefix} <- signatures do
        quote do
          def match(<<unquote(prefix)::binary, _::binary>>), do: {:ok, unquote(mime)}
        end
      end

    {guard_clauses, _seen} =
      Enum.reduce(signatures, {[], MapSet.new()}, fn {mime, prefix}, {clauses, seen} ->
        guard_name = mime_to_guard_name(mime)

        case MapSet.member?(seen, guard_name) do
          true ->
            {clauses, seen}

          false ->
            guard =
              quote do
                defguard unquote(guard_name)(bin)
                         when is_binary(bin) and
                                byte_size(bin) >= byte_size(unquote(prefix)) and
                                binary_part(bin, 0, byte_size(unquote(prefix))) == unquote(prefix)
              end

            {[guard | clauses], MapSet.put(seen, guard_name)}
        end
      end)

    signatures_fn =
      quote do
        def signatures, do: unquote(Macro.escape(signatures))
      end

    fallback =
      quote do
        def match(_), do: {:error, :unknown}
      end

    quote do
      unquote(signatures_fn)
      unquote_splicing(Enum.reverse(guard_clauses))
      unquote_splicing(match_clauses)
      unquote(fallback)
    end
  end

  defp mime_to_guard_name(mime) do
    name =
      mime
      |> String.replace(~r/[^a-zA-Z0-9]+/, "_")
      |> String.trim("_")
      |> String.downcase()

    :"is_#{name}"
  end
end
