defmodule Nexus.Intelligence.Services.DocumentExtractor do
  @moduledoc """
  Uses the Instructor library to extract structured financial data
  from unstructured text/OCR using an LLM.
  """
  # Rule 6 exception: Instructor requires `use Ecto.Schema` directly to define
  # its JSON extraction target via `embedded_schema`. This is NOT a projection.
  # `use Nexus.Schema` cannot be used here because embedded_schema is Instructor-specific.
  use Ecto.Schema
  use Instructor

  @primary_key false
  embedded_schema do
    field :vendor_name, :string
    field :invoice_number, :string
    field :amount, :decimal
    field :currency, :string
    field :invoice_date, :date
    field :due_date, :date
    field :line_items, {:array, :string}, default: []
    field :confidence_score, :float
  end

  @doc """
  Extracts invoice details from raw text.
  Requires an LLM provider configured (Ollama/OpenAI) for Instructor.
  """
  def extract(text) do
    # In a production offline environment, this would target a local
    # vLLM/Ollama instance running a model like Mistral or Llama-3.
    Instructor.chat_completion(
      model: "mistral",
      response_model: __MODULE__,
      max_retries: 3,
      messages: [
        %{
          role: "system",
          content:
            "You are a financial extraction AI. Extract the exact invoice details from the text. If a field is missing, leave it blank."
        },
        %{
          role: "user",
          content: text
        }
      ]
    )
  end
end
