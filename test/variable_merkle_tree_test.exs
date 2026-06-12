defmodule VariableMerkleTreeTest do
  alias Examples.EVariableMerkleTree

  use ExUnit.Case, async: true
  use TestHelper.TestMacro

  use TestHelper.GenerateExampleTests,
    for: EVariableMerkleTree
end
