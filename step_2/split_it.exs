Mix.install([:ecto])

# Módulos por linha
# Parser -> :7
# Calculator -> :58
# Main -> :111
# Tests -> :217

defmodule Parser do
  @moduledoc """
  Módulo responsável por realizar validações
  sobre as estruturas do desafio, sendo:

  - item
    - nome
    - quantidade
    - preço (em centavos)

  - emails únicos
  """
  defmodule Item do
    import Ecto.Changeset, only: [cast: 3, validate_required: 2, apply_action: 2]

    @types %{
      name: :string,
      price: :integer,
      amount: :integer
    }

    def changeset(attrs) do
      fields = Map.keys(@types)

      {%{}, @types}
      |> cast(attrs, fields)
      |> validate_required(fields)
      |> apply_action(:parse)
    end
  end

  @type changeset :: Ecto.Changeset.t()
  @type item :: Parser.Item.t()

  defdelegate unique_emails(emails), to: Enum, as: :uniq

  @spec parse_items(keyword) :: {list(item), list(changeset)}
  def parse_items(data) do
    Enum.reduce(data, {[], []}, fn item, acc ->
      {items, errors} = acc

      case Parser.Item.changeset(item) do
        {:ok, item} -> {[item | items], errors}
        {:error, changeset} -> {items, [changeset | errors]}
      end
    end)
  end
end

defmodule Calculator do
  @moduledoc """
  Módulo responsável por realizar os cálculos
  principais do desafio:
  - valor total da compra
  - divisão por igual do valor total pela quantidade de emails
  """

  @spec get_total_amount(list(Parser.Item.t())) :: {:ok, integer} | {:error, atom}
  def get_total_amount(items) do
    amount =
      for item <- items, reduce: 0 do
        sum -> sum + item.amount * item.price
      end

    if amount > 0 do
      {:ok, amount}
    else
      {:error, :negative_amount}
    end
  end

  @spec split_amount(list(binary), integer) :: map
  def split_amount(emails, amount) do
    issuers = length(emails)
    base = Integer.floor_div(amount, issuers)
    remainder = rem(amount, issuers)

    if remainder == 0 do
      build_receipt(emails, base)
    else
      emails
      |> build_receipt(base)
      |> Enum.map_reduce(remainder, fn
        issuer, 0 ->
          {issuer, 0}

        {k, v}, acc ->
          {{k, v + 1}, acc - 1}
      end)
      |> elem(0)
      |> Map.new()
    end
  end

  defp build_receipt(emails, amount) do
    emails
    |> Enum.map(&{&1, amount})
    |> Map.new()
  end
end

defmodule Main do
  @moduledoc """
  Módulo responsável por executar o fluxo
  do desafio, coletando informações do terminal
  e ao final, escrevendo na tela o resultado.

  Esse módulo centraliza as operações de 
  efeitos colaterais (IO).
  """
  require Logger

  def run do
    with items <- get_items(),
         emails <- get_emails() do
      process(items, emails)
    end
  end

  def process([], _), do: :error

  def process(_, []), do: :error

  def process(items, emails) do
    with emails <- Parser.unique_emails(emails),
         {items, items_errors} <- Parser.parse_items(items),
         {:ok, total_amount} <- Calculator.get_total_amount(items),
         receipt <- Calculator.split_amount(emails, total_amount) do
      print_items_parsing_errors(items_errors)
      print_result(receipt)
    else
      err -> Logger.error(err)
    end
  end

  defp get_items() do
    offset = get_integer("-> Quantos items deseja adicionar?\n")

    for _ <- 1..offset, into: [] do
      %{
        name: get_string("  -> Digite o nome do item:\n  "),
        amount: get_integer("  -> Insira a quantidade a ser comprada:\n  "),
        price: get_float_to_int("  -> Insira o preço da unidade do item:\n  ")
      }
    end
  end

  defp get_emails() do
    offset = get_integer("-> Quantos emails deseja incluir?\n")

    for _ <- 1..offset, into: [] do
      get_string("  -> Digite um email:\n  ")
    end
  end

  defp get_integer(msg) do
    msg
    |> IO.gets()
    |> remove_whitespaces()
    |> String.to_integer()
  end

  defp get_float_to_int(msg) do
    msg
    |> IO.gets()
    |> remove_whitespaces()
    |> String.to_float()
    |> Kernel.*(100)
    |> trunc()
  end

  defp get_string(msg) do
    msg
    |> IO.gets()
    |> remove_whitespaces()
  end

  defp remove_whitespaces(str) do
    str
    |> String.trim()
    |> String.replace(~r/\s/, "")
  end

  defp print_items_parsing_errors([]), do: nil

  defp print_items_parsing_errors(errors) do
    IO.puts("""
    Os seguintes items não foram lidos com sucesso
    por causa de dados inválidos: #{inspect(errors)}
    """)
  end

  defp print_result(receipt) do
    IO.puts("""
    \nEssa a conta final: #{inspect(receipt)}
    """)
  end
end

args = Enum.join(System.argv(), " ")

if String.contains?(args, "--tests") do
  ExUnit.start()
else
  Main.run()
end

defmodule Tests do
  use ExUnit.Case, async: true

  alias Parser.Item

  test "unique emails" do
    emails = ["zoey.spessanha@outlook.com", "zoey.spessanha@outlook.com"]
    unique = Parser.unique_emails(emails)

    assert length(unique) == 1
    assert ["zoey.spessanha@outlook.com"] == unique
  end

  @tag capture_log: true
  describe "process/1" do
    test "error on empty items" do
      assert :error = Main.process([], ["zoey.spessanha@outlook.com"])
    end

    test "error on empty emails" do
      {:ok, item} = Item.changeset(%{name: "dummy", amount: 1, price: 120})
      assert :error = Main.process([item], [])
    end
  end

  describe "Calculator.get_total_amount/1" do
    test "error on negative values" do
      {items, _errors} =
        Parser.parse_items([
          %{name: "dummy", amount: 1, price: 120},
          %{name: "dummy", amount: 4, price: -240}
        ])

      assert {:error, :negative_amount} = Calculator.get_total_amount(items)
    end

    test "sucess on valid values" do
      {items, _errors} =
        Parser.parse_items([
          %{name: "dummy", amount: 3, price: 50},
          %{name: "dummy", amount: 2, price: 50}
        ])

      assert {:ok, total_amount} = Calculator.get_total_amount(items)
      assert total_amount == 250
    end
  end

  describe "Calculator.split_amount/2" do
    test "base case" do
      {:ok, item} = Item.changeset(%{name: "dummy", amount: 1, price: 500})
      email = "example@from.com"

      assert {:ok, amount} = Calculator.get_total_amount([item])
      assert %{} = receipt = Calculator.split_amount([email], amount)
      assert receipt[email] == item.price
    end

    test "with odd number of emails" do
      emails = ["one@example.com", "two@example.com", "three@example.com"]

      {items, _errors} =
        Parser.parse_items([
          %{name: "dummy", amount: 2, price: 25},
          %{name: "dummy", amount: 2, price: 25}
        ])

      assert {:ok, amount} = Calculator.get_total_amount(items)
      assert amount == 100

      assert %{
               "one@example.com" => 34,
               "two@example.com" => 33,
               "three@example.com" => 33
             } = Calculator.split_amount(emails, amount)
    end

    test "with even number of emails" do
      emails = ["one@example.com", "two@example.com", "three@example.com", "four@example.com"]

      {items, _errors} =
        Parser.parse_items([
          %{name: "dummy", amount: 1, price: 51},
          %{name: "dummy", amount: 1, price: 51}
        ])

      assert {:ok, amount} = Calculator.get_total_amount(items)
      assert amount == 102

      assert %{
               "one@example.com" => 26,
               "two@example.com" => 25,
               "three@example.com" => 25,
               "four@example.com" => 26
             } = Calculator.split_amount(emails, amount)
    end
  end
end
