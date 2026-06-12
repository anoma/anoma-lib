defmodule Examples.EVariableMerkleTree do
  @moduledoc """
  I exercise VariableMerkleTree against the tree scheme of arm-openvm's
  `SparseTree` (arm_core/src/tree.rs): keccak256 hashing, "EMPTY" padding,
  minimal variable depth, and sibling flags set when the sibling is the
  left child.
  """

  require ExUnit.Assertions

  import ExUnit.Assertions

  @spec keccak(binary()) :: VariableMerkleTree.hash_size()
  def keccak(bytes) do
    ExKeccak.hash_256(bytes)
  end

  @spec leaf(byte()) :: VariableMerkleTree.hash_size()
  def leaf(byte) do
    :binary.copy(<<byte>>, 32)
  end

  @spec empty_keccak_tree() :: VariableMerkleTree.t()
  def empty_keccak_tree() do
    tree = VariableMerkleTree.new(&keccak/1)

    assert VariableMerkleTree.root(tree) == keccak("EMPTY")
    assert tree.depth == 0
    assert tree.next_index == 0

    tree
  end

  @doc """
  A three-leaf tree checked, root and proof paths both, against a hand
  derivation of the arm-openvm scheme:

      n00 = keccak(l1 <> l2)    n01 = keccak(l3 <> empty)
                root = keccak(n00 <> n01)
  """
  @spec three_leaf_tree() :: VariableMerkleTree.t()
  def three_leaf_tree() do
    [l1, l2, l3] = leaves = Enum.map(1..3, &leaf/1)
    tree = VariableMerkleTree.add(empty_keccak_tree(), leaves)

    empty = keccak("EMPTY")
    n00 = keccak(l1 <> l2)
    n01 = keccak(l3 <> empty)
    root = keccak(n00 <> n01)

    assert VariableMerkleTree.depth(tree) == 2
    assert VariableMerkleTree.root(tree) == root

    expected_paths = %{
      l1 => [{l2, false}, {n01, false}],
      l2 => [{l1, true}, {n01, false}],
      l3 => [{empty, false}, {n00, true}]
    }

    for {leaf, path} <- expected_paths do
      assert {^path, ^root} = VariableMerkleTree.generate_proof(tree, leaf)
      assert VariableMerkleTree.verify_proof(leaf, path, root, &keccak/1)
    end

    refute VariableMerkleTree.generate_proof(tree, leaf(4))

    tree
  end

  @doc """
  Incremental adds growing the tree across capacities agree with adding
  every leaf at once.
  """
  @spec grown_tree() :: VariableMerkleTree.t()
  def grown_tree() do
    leaves = Enum.map(1..5, &leaf/1)
    {first, rest} = Enum.split(leaves, 2)

    grown =
      empty_keccak_tree()
      |> VariableMerkleTree.add(first)
      |> VariableMerkleTree.add(rest)

    root =
      empty_keccak_tree()
      |> VariableMerkleTree.add(leaves)
      |> VariableMerkleTree.root()

    assert VariableMerkleTree.depth(grown) == 3
    assert VariableMerkleTree.root(grown) == root

    for leaf <- leaves do
      assert {path, ^root} = VariableMerkleTree.generate_proof(grown, leaf)
      assert VariableMerkleTree.verify_proof(leaf, path, root, &keccak/1)
    end

    grown
  end
end
