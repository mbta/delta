defmodule DeltaWeb.ErrorView do
  @moduledoc """
  Renders errors.
  """
  use DeltaWeb, :view

  # coveralls-ignore-start
  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  # coveralls-ignore-end
end
