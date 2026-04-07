defmodule Examples.ETransparent.EJSON do
  alias Examples.ETransparent.EResource
  alias Examples.ETransparent.EAction
  alias Examples.ETransparent.ETransaction

  use TestHelper.TestMacro

  @doc """
  I test the json encoding of a cps unit.
  """
  @spec cps_instance() :: String.t()
  def cps_instance do
    instance = arbitrary_cps_instance()
    Jason.encode!(instance)
  end

  @doc """
  I test the json encoding of a compliance unit.
  """
  @spec compliance_unit() :: String.t()
  def compliance_unit do
    compliance_unit = arbitrary_compliance_unit()
    Jason.encode!(compliance_unit)
  end

  @doc """
  I test the json encoding of a resource
  """
  @spec resource() :: String.t()
  def resource do
    resource = arbitrary_resource()
    Jason.encode!(resource)
  end

  @doc """
  I test the json encoding of an action.
  """
  @spec action() :: String.t()
  def action do
    action = arbitrary_action()
    Jason.encode!(action)
  end

  @doc """
  I test the json encoding of a transaction.
  """
  @spec transaction() :: String.t()
  def transaction do
    transaction = arbitrary_transaction()
    Jason.encode!(transaction)
  end

  ############################################################
  #                           Helpers                        #
  ############################################################

  @spec arbitrary_transaction() :: Anoma.RM.Transparent.Transaction.t()
  def arbitrary_transaction do
    ETransaction.single_swap()
  end

  @spec arbitrary_action() :: Anoma.RM.Transparent.Action.t()
  def arbitrary_action do
    EAction.trivial_swap_action()
  end

  @spec arbitrary_resource() :: Anoma.RM.Transparent.Resource.t()
  def arbitrary_resource do
    EResource.trivial_false_resource()
  end

  @spec arbitrary_compliance_unit() :: term()
  def arbitrary_compliance_unit do
    arbitrary_action()
    |> Map.get(:compliance_units)
    |> Enum.into([])
    |> hd()
  end

  @spec arbitrary_cps_instance() ::
          Anoma.RM.Transparent.ProvingSystem.CPS.Instance.t()
  def arbitrary_cps_instance do
    arbitrary_action()
    |> Map.get(:instance)
  end
end
