defmodule Nexus.Router do
  @moduledoc """
  The Commanded Router for the Nexus application.
  Dispatches commands to the appropriate domain aggregates.
  """
  use Commanded.Commands.Router

  # Global Middleware Stack
  middleware(Nexus.Shared.Middleware.CorrelationId)
  middleware(Nexus.Shared.Middleware.TenantGate)

  dispatch(Nexus.Identity.Commands.RegisterUser,
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )

  dispatch([Nexus.Identity.Commands.VerifyBiometric, Nexus.Identity.Commands.VerifyStepUp],
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )

  dispatch(
    [
      Nexus.Identity.Commands.UpdateSettings,
      Nexus.Identity.Commands.StartSession,
      Nexus.Identity.Commands.ExpireSession
    ],
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )

  dispatch(Nexus.Identity.Commands.RegisterSystemAdmin,
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )

  dispatch([Nexus.Identity.Commands.ChangeUserRole, Nexus.Identity.Commands.RevokeUserRole],
    to: Nexus.Identity.Aggregates.User,
    identity: :user_id
  )

  # --- Organization Domain ---
  dispatch(Nexus.Organization.Commands.ProvisionTenant,
    to: Nexus.Organization.Aggregates.Tenant,
    identity: :org_id
  )

  dispatch(Nexus.Organization.Commands.InviteUser,
    to: Nexus.Organization.Aggregates.Tenant,
    identity: :org_id
  )

  dispatch(Nexus.Organization.Commands.RedeemInvitation,
    to: Nexus.Organization.Aggregates.Tenant,
    identity: :org_id
  )

  dispatch(
    [Nexus.Organization.Commands.SuspendTenant, Nexus.Organization.Commands.ToggleTenantModule],
    to: Nexus.Organization.Aggregates.Tenant,
    identity: :org_id
  )

  # --- ERP Domain ---
  dispatch(Nexus.ERP.Commands.IngestInvoice,
    to: Nexus.ERP.Aggregates.Invoice,
    identity: :invoice_id
  )

  dispatch(Nexus.ERP.Commands.UploadStatement,
    to: Nexus.ERP.Aggregates.Statement,
    identity: :statement_id
  )

  dispatch(Nexus.ERP.Commands.MatchInvoice,
    to: Nexus.ERP.Aggregates.Invoice,
    identity: :invoice_id
  )

  # --- Treasury Domain ---
  dispatch(Nexus.Treasury.Commands.RecordMarketTick,
    to: Nexus.Treasury.Aggregates.Market,
    identity: :pair
  )

  dispatch(Nexus.Treasury.Commands.CalculateExposure,
    to: Nexus.Treasury.Aggregates.Exposure,
    identity: :id
  )

  dispatch(
    [
      Nexus.Treasury.Commands.RequestTransfer,
      Nexus.Treasury.Commands.AuthorizeTransfer,
      Nexus.Treasury.Commands.ExecuteTransfer
    ],
    to: Nexus.Treasury.Aggregates.Transfer,
    identity: :transfer_id
  )

  dispatch(Nexus.Treasury.Commands.SetTransferThreshold,
    to: Nexus.Treasury.Aggregates.Policy,
    identity: :policy_id
  )

  dispatch(Nexus.Treasury.Commands.SetPolicyMode,
    to: Nexus.Treasury.Aggregates.Policy,
    identity: :policy_id
  )

  dispatch(Nexus.Treasury.Commands.EvaluateExposurePolicy,
    to: Nexus.Treasury.Aggregates.Policy,
    identity: :policy_id
  )

  dispatch(Nexus.Treasury.Commands.ConfigureModeThresholds,
    to: Nexus.Treasury.Aggregates.Policy,
    identity: :policy_id
  )

  dispatch(Nexus.Treasury.Commands.GenerateForecast,
    to: Nexus.Treasury.Aggregates.Forecast,
    identity: &__MODULE__.forecast_identity/1
  )

  dispatch(Nexus.Treasury.Commands.ReconcileTransaction,
    to: Nexus.Treasury.Aggregates.Reconciliation,
    identity: :reconciliation_id
  )

  dispatch(Nexus.Treasury.Commands.ProposeReconciliation,
    to: Nexus.Treasury.Aggregates.Reconciliation,
    identity: :reconciliation_id
  )

  dispatch(Nexus.Treasury.Commands.ApproveReconciliation,
    to: Nexus.Treasury.Aggregates.Reconciliation,
    identity: :reconciliation_id
  )

  dispatch(Nexus.Treasury.Commands.RejectReconciliation,
    to: Nexus.Treasury.Aggregates.Reconciliation,
    identity: :reconciliation_id
  )

  dispatch(Nexus.Treasury.Commands.ReverseReconciliation,
    to: Nexus.Treasury.Aggregates.Reconciliation,
    identity: :reconciliation_id
  )

  dispatch(Nexus.Treasury.Commands.RebalancePortfolio,
    to: Nexus.Treasury.Aggregates.Portfolio,
    identity: :portfolio_id
  )

  dispatch(Nexus.Treasury.Commands.InitializeNettingCycle,
    to: Nexus.Treasury.Aggregates.Netting,
    identity: :netting_id
  )

  dispatch(Nexus.Treasury.Commands.ScanInvoicesForNetting,
    to: Nexus.Treasury.Aggregates.Netting,
    identity: :netting_id
  )

  dispatch(Nexus.Treasury.Commands.AddInvoiceToNetting,
    to: Nexus.Treasury.Aggregates.Netting,
    identity: :netting_id
  )

  dispatch(
    [
      Nexus.Treasury.Commands.RegisterVault,
      Nexus.Treasury.Commands.SyncVaultBalance,
      Nexus.Treasury.Commands.DebitVault,
      Nexus.Treasury.Commands.CreditVault
    ],
    to: Nexus.Treasury.Aggregates.Vault,
    identity: :vault_id
  )

  # Command validation and enrichment
  # middleware(Nexus.Shared.Middleware.Logger)

  # --- Intelligence Domain ---
  dispatch(
    [
      Nexus.Intelligence.Commands.AnalyzeInvoice,
      Nexus.Intelligence.Commands.AnalyzeSentiment,
      Nexus.Intelligence.Commands.ResolveAnomaly,
      Nexus.Intelligence.Commands.AnalyzeTreasuryMovement,
      Nexus.Intelligence.Commands.AnalyzeReconciliation
    ],
    to: Nexus.Intelligence.Aggregates.Analysis,
    identity: :analysis_id
  )

  # --- Payments Domain ---
  dispatch(Nexus.Payments.Commands.InitiateBulkPayment,
    to: Nexus.Payments.Aggregates.BulkPayment,
    identity: :bulk_payment_id
  )

  dispatch(Nexus.Payments.Commands.FinalizeBulkPayment,
    to: Nexus.Payments.Aggregates.BulkPayment,
    identity: :bulk_payment_id
  )

  dispatch(
    [
      Nexus.Payments.Commands.InitiateExternalPayment,
      Nexus.Payments.Commands.SettleExternalPayment,
      Nexus.Payments.Commands.FailExternalPayment
    ],
    to: Nexus.Payments.Aggregates.Payment,
    identity: :payment_id
  )

  # --- Cross-Domain Domain ---
  dispatch(Nexus.CrossDomain.Commands.CreateNotification,
    to: Nexus.CrossDomain.Aggregates.Notification,
    identity: :id
  )

  dispatch(Nexus.CrossDomain.Commands.MarkNotificationRead,
    to: Nexus.CrossDomain.Aggregates.Notification,
    identity: :id
  )

  # --- Identity Helpers ---
  @spec forecast_identity(map()) :: String.t()
  def forecast_identity(%{org_id: org_id, currency: currency}), do: "forecast-#{org_id}-#{currency}"
end
