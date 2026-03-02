defmodule Nexus.Intelligence.Services.SentimentAnalyzer do
  @moduledoc """
  Service for running text classification via Bumblebee to score sentiment.
  """

  @doc """
  Returns the Bumblebee serving to be started by the application supervisor.
  Uses a distilled RoBERTa model tuned for sentiment analysis.
  """
  def serving do
    {:ok, model_info} =
      Bumblebee.load_model({:hf, "cardiffnlp/twitter-roberta-base-sentiment-latest"})

    # The cardiffnlp model repo doesn't have tokenizer.json, so we pull the base RoBERTa tokenizer
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "roberta-base"})

    Bumblebee.Text.text_classification(model_info, tokenizer,
      compile: [batch_size: 1, sequence_length: 128],
      defn_options: [compiler: EXLA]
    )
  end

  @doc """
  Runs synchronous sentiment inference using the globally supervised serving.
  """
  def analyze(text) do
    # Run against the global named serving
    result = Nx.Serving.batched_run(Nexus.Intelligence.SentimentServing, text)

    # result = %{predictions: [%{label: "positive", score: 0.98}, ...]}
    top_prediction = List.first(result.predictions)

    {:ok,
     %{
       sentiment: String.downcase(top_prediction.label),
       confidence: top_prediction.score
     }}
  end
end
