defmodule DeployTemplateWeb.PageController do
  use DeployTemplateWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
