defmodule VariableMerkleTree do
  @moduledoc """
  I implement merkle tree behaviour for use within local domain applications.

  Has a variable depth.
  """

  import Bitwise
  use TypedStruct

  alias __MODULE__

  @typedoc """
  I am the type of the hash length used by the merkle tree
  """
  @type hash_size :: <<_::256>>

  @typedoc """
  I am the type of the hash function used for the tree
  """
  @type hash_fn :: (binary() -> hash_size())

  @typedoc """
  I am the type of the merkle path.

  I represent a list of node neighbors alongside a flag telling whether the
  neighbor is left or right.
  """
  @type path() :: [{hash_size, boolean}]

  typedstruct enforce: true do
    # the choice of a 256-bit hash function
    field(:hash_fn, hash_fn(), default: &__MODULE__.hash/1)

    # map from levels to the map from index to the node
    field(:nodes, %{integer() => %{integer() => hash_size()}},
      default: %{
        0 => %{}
      }
    )

    # map of the sparse nodes on every level
    field(:empty_nodes, %{integer() => hash_size()})

    # index of the next commitment added
    field(:next_index, non_neg_integer(), default: 0)

    # how many commitments can the current tree support
    field(:capacity, non_neg_integer(), default: 1)

    # leaf map with leaves as keys
    # for efficient path computation
    field(:leaf_map, %{hash_size() => non_neg_integer()}, default: %{})
  end

  @doc """
  I hash some bytes with a selected hash funciton
  """
  @spec hash(binary()) :: hash_size()
  @spec hash(hash_fn, binary()) :: hash_size()
  def hash(hash_fn \\ fn x -> :crypto.hash(:sha256, x) end, bytes) do
    hash_fn.(bytes)
  end

  @doc """
  I am the hash of a sparse "empty" node

  Literally the hash of the string "EMPTY"
  """
  @spec empty() :: hash_size()
  @spec empty(hash_fn()) :: hash_size()
  def empty(hash_fn \\ fn x -> :crypto.hash(:sha256, x) end) do
    hash(hash_fn, "EMPTY")
  end

  @doc """
  I create a new variable size sparse merkle tree
  """
  @spec new() :: t()
  @spec new(hash_fn()) :: t()
  def new(hash_fn \\ fn x -> :crypto.hash(:sha256, x) end) do
    # Assume we have a tree at most of depth 32
    empty_nodes =
      for i <- 1..31, reduce: %{0 => empty(hash_fn)} do
        acc ->
          previous_empty_hash = Map.get(acc, i - 1)

          Map.put(
            acc,
            i,
            hash(
              hash_fn,
              previous_empty_hash <> previous_empty_hash
            )
          )
      end

    %VariableMerkleTree{
      empty_nodes: empty_nodes,
      hash_fn: hash_fn,
      nodes: %{0 => %{0 => empty(hash_fn)}}
    }
  end

  @doc """
  I calculate the depth of a given tree
  """
  @spec depth(t()) :: non_neg_integer()
  def depth(tree) do
    tree.capacity |> :math.log2() |> trunc()
  end

  @doc """
  I return the root of the given tree
  """
  @spec root(t()) :: hash_size()
  def root(tree) do
    Map.get(Map.get(tree.nodes, depth(tree)), 0)
  end

  @doc """
  Given a tree and a list of leaves, I add the leaves to the tree.
  """
  @spec add(t(), [hash_size()]) :: t()
  def add(tree, leaves) do
    index = tree.next_index

    # Compute the new leaf map and new commitment length
    # in the same loop
    {new_leaf_map, new_commitment_length} =
      for leaf <- leaves, reduce: {tree.leaf_map, index} do
        {map_acc, index_acc} ->
          {Map.put(map_acc, leaf, index_acc), index_acc + 1}
      end

    {depth, capacity} =
      if new_commitment_length > tree.capacity do
        # If the tree capacity is exceeded, calculate the new minimal depth
        new_depth =
          new_commitment_length |> :math.log2() |> :math.ceil() |> trunc()

        {new_depth, Integer.pow(2, new_depth)}
      else
        {depth(tree), tree.capacity}
      end

    # Add leaves and recompute needed intermediary nodes
    new_nodes =
      compute_nodes(
        tree.hash_fn,
        depth,
        tree.nodes,
        tree.empty_nodes,
        index,
        leaves
      )

    %VariableMerkleTree{
      tree
      | nodes: new_nodes,
        next_index: new_commitment_length,
        capacity: capacity,
        leaf_map: new_leaf_map
    }
  end

  @doc """
  Given a tree and a hash, generate a merkle path to the leaf, nil if absent.
  """
  @spec generate_proof(t(), hash_size()) :: {path(), hash_size()} | nil
  def generate_proof(tree, leaf) do
    # Get the index of the leaf
    index_found = Map.get(tree.leaf_map, leaf)
    # fetch the hash function
    hash_fn = tree.hash_fn

    if index_found do
      {path, root, _index} =
        for i <- 0..(depth(tree) - 1)//1,
            reduce: {[], leaf, index_found} do
          {path, node, index} ->
            # Take the current level of the tree
            current_nodes = Map.get(tree.nodes, i)

            is_left = (index &&& 1) == 0

            empty = Map.get(tree.empty_nodes, i)

            if is_left do
              # If the node is a left one, take its right sibling
              sibling = Map.get(current_nodes, index + 1, empty)

              # Hash the node on the left and sibling on the right
              # The index of its parents is going to be index / 2
              {path ++ [{sibling, true}], hash(hash_fn, node <> sibling),
               div(index, 2)}
            else
              # If the node is a right one, take its left sibling
              sibling = Map.get(current_nodes, index - 1)

              # Hash the node on the right and sibling on the left
              # The index of its parents is going to be (index - 1) / 2
              {path ++ [{sibling, false}], hash(hash_fn, sibling <> node),
               div(index - 1, 2)}
            end
        end

      {path, root}
    end
  end

  @doc """
  Given a leaf, a path, and a root with a corresponding hash function, verify
  that the path starting with the leaf produces the root.
  """
  @spec verify_proof(hash_size(), path(), hash_size(), hash_fn()) :: boolean()
  def verify_proof(leaf, path, root, hash_fn) do
    calculated_root =
      Enum.reduce(path, leaf, fn {neighbour, is_left}, acc ->
        if is_left do
          hash(hash_fn, acc <> neighbour)
        else
          hash(hash_fn, neighbour <> acc)
        end
      end)

    calculated_root == root
  end

  @spec compute_nodes(
          hash_fn(),
          non_neg_integer,
          %{integer() => %{integer() => hash_size()}},
          %{integer() => hash_size()},
          non_neg_integer(),
          [hash_size()]
        ) :: %{integer() => %{integer() => hash_size()}}
  defp compute_nodes(hash_fn, depth, nodes, empty_nodes, index, leaves) do
    # Iterate over each level of the tree, updating
    # only the parent nodes of the given leaves
    {new_nodes, _, _} =
      for i <- 0..depth, reduce: {nodes, index, leaves} do
        {acc_nodes, index, nodes} ->
          # Fetch the current level of the tree
          current_nodes = Map.get(acc_nodes, i, %{})

          # If the first node is the right one, fetch its sibling
          initial_left_sibling =
            if is_left(index) do
              nil
            else
              Map.get(current_nodes, index - 1)
            end

          # Iterate over all the nodes
          # Populate the current level with them
          # Also calculate the list of parent nodes
          {updated_current_nodes, parents, _, final_left_sibling} =
            for node <- nodes,
                reduce: {current_nodes, [], index, initial_left_sibling} do
              {acc_current_nodes, parents, j, left_sibling} ->
                if left_sibling do
                  # Hash the left sibling with the current node
                  {Map.put(acc_current_nodes, j, node),
                   [hash(hash_fn, left_sibling <> node) | parents], j + 1,
                   nil}
                else
                  # record the current node as a left sibling
                  {Map.put(acc_current_nodes, j, node), parents, j + 1, node}
                end
            end

          # If the final node was a left one, we have to compute one more parent
          # by hashing with an empty node of the appropriate level
          final_parents =
            if final_left_sibling do
              [
                hash(hash_fn, final_left_sibling <> Map.get(empty_nodes, i))
                | parents
              ]
            else
              parents
            end

          {Map.put(acc_nodes, i, updated_current_nodes), div(index, 2),
           Enum.reverse(final_parents)}
      end

    new_nodes
  end

  @spec is_left(non_neg_integer()) :: boolean()
  defp is_left(index) do
    (index &&& 1) == 0
  end
end
