defmodule Anoma.RM.OpenVM.TransactionRecord do
  @moduledoc """
  I am a completed arm-openvm transaction, held as the prover's opaque bincode blob.

  ### Public API
  - `verify/1`
  - `nullifiers/1`
  - `commitments/1`
  - `roots/1`
  - `from_noun/1`
  """

  alias __MODULE__
  use TypedStruct

  @behaviour Noun.Nounable.Kind

  typedstruct enforce: true do
    # bincode-encoded arm-openvm transaction
    field(:bytes, binary(), default: <<>>)
  end

  @doc """
  Verify the ransaction in one shot via the NIF.
  """
  @spec verify(t()) :: boolean() | {:error, term()}
  def verify(%TransactionRecord{bytes: bytes}) do
    ArmOpenvm.Verifier.verify_transaction(bytes)
  end

  @doc "Nullifiers (32-byte binaries) in transaction order."
  @spec nullifiers(t()) :: [<<_::256>>] | {:error, term()}
  def nullifiers(%TransactionRecord{bytes: bytes}) do
    ArmOpenvm.Verifier.transaction_nullifiers(bytes)
  end

  @doc "Commitments (32-byte binaries) in transaction order."
  @spec commitments(t()) :: [<<_::256>>] | {:error, term()}
  def commitments(%TransactionRecord{bytes: bytes}) do
    ArmOpenvm.Verifier.transaction_commitments(bytes)
  end

  @doc "Consumed-resource roots for anchor checks."
  @spec roots(t()) :: [<<_::256>>] | {:error, term()}
  def roots(%TransactionRecord{bytes: bytes}) do
    ArmOpenvm.Verifier.transaction_roots(bytes)
  end

  @spec from_noun(Noun.t()) :: {:ok, t()} | :error
  def from_noun(bytes) when is_binary(bytes) or is_integer(bytes) do
    {:ok, %TransactionRecord{bytes: Noun.atom_integer_to_binary(bytes)}}
  end

  def from_noun(_), do: :error

  defimpl Noun.Nounable, for: TransactionRecord do
    @impl true
    def to_noun(%TransactionRecord{bytes: bytes}), do: bytes
  end
end

defimpl Anoma.RM.Intent, for: Anoma.RM.OpenVM.TransactionRecord do
  alias Anoma.RM.OpenVM.TransactionRecord

  @impl true
  def verify(tr = %TransactionRecord{}) do
    case TransactionRecord.verify(tr) do
      true -> true
      false -> {:error, "openvm transaction verification failed"}
      {:error, _} = err -> err
    end
  end

  @impl true
  def nullifiers(tr = %TransactionRecord{}) do
    tr |> TransactionRecord.nullifiers() |> MapSet.new()
  end

  @impl true
  def commitments(tr = %TransactionRecord{}) do
    tr |> TransactionRecord.commitments() |> MapSet.new()
  end

  # A proven transaction's proofs bind the full bundle, so two cannot be
  # merged after the fact — composition must happen before proving.
  @impl true
  def compose(%TransactionRecord{}, %TransactionRecord{}) do
    raise "openvm transactions cannot be composed"
  end
end
