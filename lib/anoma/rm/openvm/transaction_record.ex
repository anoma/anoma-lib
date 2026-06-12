defmodule Anoma.RM.OpenVM.TransactionRecord do
  @moduledoc """
  I am a completed arm-openvm transaction, held as the prover's opaque bincode blob.

  ### Public API
  - `verify/1`
  - `verify_and_extract/1`
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
  Verify the transaction in one shot via the NIF.
  """
  @spec verify(t()) :: boolean() | {:error, term()}
  def verify(%TransactionRecord{bytes: bytes}) do
    ArmOpenvm.Verifier.verify_transaction(bytes)
  end

  @doc """
  Verify and extract in one NIF pass. Returns `{consumed, created, roots}`,
  where each `consumed`/`created` entry is `{tag, app_data_blobs}` on success
  """
  @spec verify_and_extract(t()) ::
          {[{<<_::256>>, ArmOpenvm.Verifier.app_data_blobs()}],
           [{<<_::256>>, ArmOpenvm.Verifier.app_data_blobs()}], [<<_::256>>]}
          | {:error, term()}
  def verify_and_extract(%TransactionRecord{bytes: bytes}) do
    ArmOpenvm.Verifier.verify_and_extract(bytes)
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
  def from_noun([size | bytes])
      when (is_binary(bytes) or is_integer(bytes)) and
             (is_binary(size) or is_integer(size)) do
    {:ok,
     %TransactionRecord{
       bytes:
         Noun.atom_integer_to_binary(
           bytes,
           Noun.atom_binary_to_integer(size)
         )
     }}
  end

  def from_noun(_), do: :error

  defimpl Noun.Nounable, for: TransactionRecord do
    @impl true
    def to_noun(%TransactionRecord{bytes: bytes}) do
      [byte_size(bytes) | bytes]
    end
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
    case TransactionRecord.nullifiers(tr) do
      nullifiers when is_list(nullifiers) ->
        MapSet.new(nullifiers)

      {:error, reason} ->
        raise ArgumentError,
              "undecodable openvm transaction: #{inspect(reason)}"
    end
  end

  @impl true
  def commitments(tr = %TransactionRecord{}) do
    case TransactionRecord.commitments(tr) do
      commitments when is_list(commitments) ->
        MapSet.new(commitments)

      {:error, reason} ->
        raise ArgumentError,
              "undecodable openvm transaction: #{inspect(reason)}"
    end
  end

  # A proven transaction's proofs bind the full bundle, so two cannot be
  # merged after the fact — composition must happen before proving.
  @impl true
  def compose(%TransactionRecord{}, %TransactionRecord{}) do
    raise "openvm transactions cannot be composed"
  end
end
