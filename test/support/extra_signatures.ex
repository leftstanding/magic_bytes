defmodule MagicBytes.Test.ExtraSignatures do
  use MagicBytes.DefineSignatures, guards: true

  # Bytes chosen to not overlap with any built-in signature
  defsignature("application/x-custom", <<0xDE, 0xAD, 0xC0, 0xDE>>)
  defsignature_at("application/x-custom-offset", 4, <<0xBE, 0xEF>>)
end
