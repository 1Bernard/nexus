defmodule Nexus.CrossDomain.Queries.SearchQuery do
  @moduledoc """
  Multi-domain search queries for the Command Palette.
  Searches across Invoices and Statements using ILIKE for partial matching.
  """
  import Ecto.Query

  alias Nexus.ERP.Projections.{Invoice, Statement}

  @doc "Searches invoices by SAP document number, entity ID, or subsidiary."
  @spec search_invoices(Nexus.Types.org_id(), String.t()) :: Ecto.Query.t()
  def search_invoices(org_id, term) do
    pattern = "%#{term}%"

    query =
      from(i in Invoice,
        where:
          ilike(i.sap_document_number, ^pattern) or
            ilike(i.entity_id, ^pattern) or
            ilike(i.subsidiary, ^pattern),
        order_by: [desc: i.created_at],
        limit: 5,
        select: %{
          id: i.id,
          path: "/invoices",
          label: fragment("'Invoice ' || ?", i.sap_document_number),
          detail: fragment("? || ' · ' || ? || ' ' || ?", i.subsidiary, i.currency, i.amount),
          icon: "hero-document-text"
        }
      )

    scope_by_org(query, org_id)
  end

  @doc "Searches statements by filename."
  @spec search_statements(Nexus.Types.org_id(), String.t()) :: Ecto.Query.t()
  def search_statements(org_id, term) do
    pattern = "%#{term}%"

    query =
      from(s in Statement,
        where: ilike(s.filename, ^pattern),
        order_by: [desc: s.created_at],
        limit: 5,
        select: %{
          id: s.id,
          path: "/statements",
          label: fragment("'Statement: ' || ?", s.filename),
          detail: fragment("? || ' · ' || ? || ' lines'", s.format, s.line_count),
          icon: "hero-document-arrow-up"
        }
      )

    scope_by_org(query, org_id)
  end

  defp scope_by_org(query, :all), do: query
  defp scope_by_org(query, org_id), do: where(query, [q], q.org_id == ^org_id)
end
