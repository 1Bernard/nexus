defmodule Nexus.Mailer do
  @moduledoc """
  Swoosh mailer adapter for Nexus. Used to send transactional emails such as
  passwordless login links and notification digests.
  """
  use Swoosh.Mailer, otp_app: :nexus
end
