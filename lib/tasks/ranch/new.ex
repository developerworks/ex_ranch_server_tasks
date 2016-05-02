defmodule Mix.Tasks.Ranch.New do
  use Mix.Task

  import Mix.Generator
  import Mix.Utils, only: [camelize: 1, underscore: 1]

  @shortdoc "Creates a new ranch server project"

  @moduledoc """
  Creates a new Elixir project.
  It expects the path of the project as argument.

      mix new PATH [--sup] [--module MODULE] [--app APP] [--umbrella]

  A project at the given PATH  will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.

  A `--sup` option can be given to generate an OTP application
  skeleton including a supervision tree. Normally an app is
  generated without a supervisor and without the app callback.

  An `--umbrella` option can be given to generate an
  umbrella project.

  An `--app` option can be given in order to
  name the OTP application for the project.

  A `--module` option can be given in order
  to name the modules in the generated code skeleton.

  ## Examples

      mix new hello_world

  Is equivalent to:

      mix new hello_world --module HelloWorld

  To generate an app with supervisor and application callback:

      mix new hello_world --sup

  """

  @spec run(OptionParser.argv) :: :ok
  def run(argv) do
    {opts, argv, _} = OptionParser.parse(argv, switches: [sup: :boolean, umbrella: :boolean])

    case argv do
      [] ->
        Mix.raise "Expected PATH to be given, please use \"mix new PATH\""
      [path|_] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !!opts[:app])
        mod = opts[:module] || camelize(app)
        check_mod_name_validity!(mod)
        check_mod_name_availability!(mod)
        File.mkdir_p!(path)

        File.cd! path, fn ->
          if opts[:umbrella] do
            do_generate_umbrella(app, mod, path, opts)
          else
            do_generate(app, mod, path, opts)
          end
        end
    end
  end

  defp do_generate(app, mod, path, opts) do
    assigns = [app: app, mod: mod, otp_app: otp_app(mod, !!opts[:sup]),
               version: get_version(System.version)]

    create_file "README.md",  readme_template(assigns)
    create_file ".gitignore", gitignore_text
    create_file ".editorconfig", editorconfig_text

    if in_umbrella? do
      create_file "mix.exs", mixfile_apps_template(assigns)
    else
      create_file "mix.exs", mixfile_template(assigns)
    end

    create_directory "config"
    create_file "config/config.exs", config_template(assigns)
    create_file "config/dev.exs", config_dev_template(assigns)
    create_file "config/prod.exs", config_prod_template(assigns)
    create_file "config/test.exs", config_test_template(assigns)

    create_directory "lib"
    module_path = Path.join("lib", app)
    create_directory module_path

    create_file module_path <> "/" <> "ssl_acceptor.ex", ssl_acceptor_template(assigns)
    create_file module_path <> "/" <> "tcp_acceptor.ex", tcp_acceptor_template(assigns)
    create_file module_path <> "/" <> "ssl_protocol_handler.ex", ssl_protocol_handler_template(assigns)
    create_file module_path <> "/" <> "tcp_protocol_handler.ex", tcp_protocol_handler_template(assigns)

    if opts[:sup] do
      create_file "lib/#{app}.ex", lib_sup_template(assigns)
    else
      create_file "lib/#{app}.ex", lib_template(assigns)
    end

    create_directory "test"
    create_file "test/test_helper.exs", test_helper_template(assigns)
    create_file "test/#{app}_test.exs", test_template(assigns)

    Mix.shell.info """

    Your Mix project was created successfully.
    You can use "mix" to compile it, test it, and more:

        cd #{path}
        mix test

    Run "mix help" for more commands.
    """
  end

  defp otp_app(_mod, false) do
    "    [applications: [:logger]]"
  end

  defp otp_app(mod, true) do
    "    [applications: [:logger],\n     mod: {#{mod}, []}]"
  end

  defp do_generate_umbrella(_app, mod, path, _opts) do
    assigns = [app: nil, mod: mod]

    create_file ".gitignore", gitignore_text
    create_file "README.md", readme_template(assigns)
    create_file "mix.exs", mixfile_umbrella_template(assigns)

    create_directory "apps"

    create_directory "config"
    create_file "config/config.exs", config_umbrella_template(assigns)

    Mix.shell.info """

    Your umbrella project was created successfully.
    Inside your project, you will find an apps/ directory
    where you can create and host many apps:

        cd #{path}
        cd apps
        mix new my_app

    Commands like "mix compile" and "mix test" when executed
    in the umbrella project root will automatically run
    for each application in the apps/ directory.
    """
  end

  defp check_application_name!(name, from_app_flag) do
    unless name =~ ~r/^[a-z][\w_]*$/ do
      Mix.raise "Application name must start with a letter and have only lowercase " <>
                "letters, numbers and underscore, got: #{inspect name}" <>
                (if !from_app_flag do
                  ". The application name is inferred from the path, if you'd like to " <>
                  "explicitly name the application then use the \"--app APP\" option."
                else
                  ""
                end)
    end
  end

  defp check_mod_name_validity!(name) do
    unless name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      Mix.raise "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect name}"
    end
  end

  defp check_mod_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  defp get_version(version) do
    {:ok, version} = Version.parse(version)
    "#{version.major}.#{version.minor}" <>
      case version.pre do
        [h|_] -> "-#{h}"
        []    -> ""
      end
  end

  defp in_umbrella? do
    apps = Path.dirname(File.cwd!)

    try do
      Mix.Project.in_project(:umbrella_check, "../..", fn _ ->
        path = Mix.Project.config[:apps_path]
        path && Path.expand(path) == apps
      end)
    catch
      _, _ -> false
    end
  end

  embed_template :readme, """
  # <%= @mod %>

  **TODO: Add description**
  <%= if @app do %>
  ## Installation

  If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

    1. Add <%= @app %> to your list of dependencies in `mix.exs`:

          def deps do
            [{:<%= @app %>, "~> 0.0.1"}]
          end

    2. Ensure <%= @app %> is started before your application:

          def application do
            [applications: [:<%= @app %>]]
          end
  <% end %>
  """
  embed_text :editorconfig, """
  # This .editorconfig file located in project root
  root = true

  # All file types default settings
  [*]
  indent_style = space
  indent_size = 2
  end_of_line = lf
  charset = utf-8
  trim_trailing_whitespace = true
  insert_final_newline = true
  """

  embed_text :gitignore, """
  /_build
  /cover
  /deps
  erl_crash.dump
  *.ez
  """

  embed_template :mixfile, """
  defmodule <%= @mod %>.Mixfile do
    use Mix.Project

    def project do
      [app: :<%= @app %>,
       version: "0.0.1",
       elixir: "~> <%= @version %>",
       build_embedded: Mix.env == :prod,
       start_permanent: Mix.env == :prod,
       deps: deps]
    end

    def application do
  <%= @otp_app %>
    end

    defp deps do
      [
        {:ranch, "~> 1.0"}
      ]
    end
  end
  """

  embed_template :mixfile_apps, """
  defmodule <%= @mod %>.Mixfile do
    use Mix.Project

    def project do
      [app: :<%= @app %>,
       version: "0.0.1",
       build_path: "../../_build",
       config_path: "../../config/config.exs",
       deps_path: "../../deps",
       lockfile: "../../mix.lock",
       elixir: "~> <%= @version %>",
       build_embedded: Mix.env == :prod,
       start_permanent: Mix.env == :prod,
       deps: deps]
    end

    def application do
  <%= @otp_app %>
    end

    defp deps do
      [
        {:ranch, "~> 1.0"}
      ]
    end
  end
  """

  embed_template :mixfile_umbrella, """
  defmodule <%= @mod %>.Mixfile do
    use Mix.Project

    def project do
      [apps_path: "apps",
       build_embedded: Mix.env == :prod,
       start_permanent: Mix.env == :prod,
       deps: deps]
    end

    defp deps do
      [
        {:ranch, "~> 1.0"}
      ]
    end
  end
  """

  embed_template :config, ~S"""
  use Mix.Config
  import_config "#{Mix.env}.exs"
  """

  embed_template :config_dev, ~S"""
  use Mix.Config
  config :<%= @app %>, ranch: [
    {:profile, true},
    {:listener_name, :<%= @app %>_listener},
    {:acceptors, 5},
    {:transport, :ranch_ssl},
    {:transport_options, [port: 443]}
  ]
  """

  embed_template :config_prod, ~S"""
  use Mix.Config
  config :<%= @app %>, ranch: [
    {:profile, true},
    {:listener_name, :<%= @app %>_listener},
    {:acceptors, 5},
    {:transport, :ranch_ssl},
    {:transport_options, [port: 443]}
  ]
  """

  embed_template :config_test, ~S"""
  use Mix.Config
  config :<%= @app %>, ranch: [
    {:profile, true},
    {:listener_name, :<%= @app %>_listener},
    {:acceptors, 5},
    {:transport, :ranch_ssl},
    {:transport_options, [port: 443]}
  ]
  """

  embed_template :config_umbrella, ~S"""
  use Mix.Config

  import_config "../apps/*/config/config.exs"
  """

  embed_template :lib, """
  defmodule <%= @mod %> do
  end
  """

  embed_template :ssl_acceptor, """
  require Logger

  defmodule <%= @mod %>.SslAcceptor do
    @config Application.get_env(:<%= @app %>, :ranch)
    def start_link do
      {:ok, _} = :ranch.start_listener(
        @config[:listener_name],
        @config[:acceptors],
        @config[:transport],
        @config[:transport_options],
        <%= @mod %>.SslProtocolHander,
        []
      )
    end
  end
  """
  embed_template :tcp_acceptor, """
  require Logger

  defmodule <%= @mod %>.TcpAcceptor do
    @config Application.get_env(:<%= @app %>, :ranch)
    def start_link do
      {:ok, _} = :ranch.start_listener(
        @config[:listener_name],
        @config[:acceptors],
        @config[:transport],
        @config[:transport_options],
        <%= @mod %>.TcpProtocolHander,
        []
      )
    end
  end
  """
  embed_template :ssl_protocol_handler, """
  require Logger
  defmodule <%= @mod %>.SslProtocolHander do

    def start_link(ref, socket, transport, opts \\\\ []) do
      :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
    end

    def init(ref, socket, transport, opts \\\\ []) do
      :erlang.process_flag(:trap_exit, true)
      :ok = :proc_lib.init_ack({:ok, self()})
      :ok = :ranch.accept_ack(ref)
      :ok = transport.setopts(socket, [{:active, :once}])
      state = %{
        socket: socket,
        transport: transport
      }
      :gen_server.enter_loop(__MODULE__, [], state)
    end

    def handle_info({:tcp, _socket, data}, %{socket: socket,transport: transport} = state) do
      :ok = transport.setopts(socket, [{:active, :once}])
      # Do something
    end

    def handle_info({:tcp_closed, _socket}, state) do
      Logger.warn "Connection closed by client socket = \#{inspect state.socket}."
      {:stop, :normal, state}
    end

    def handle_info(:timeout, state) do
      {:noreply, state}
    end

    def handle_info({:tcp_error, _socket, reason}, state) do
      :ok = state.transport.close(state.socket)
      {:stop, state}
    end

    def handle_info({:'EXIT', pid, reason}, state) do
      {:noreply, state}
    end

    def terminate(reason, state) do
      :ok
    end

    def code_change(_old_vsn, state, _extra) do
      {:ok, state}
    end
  end
  """

  embed_template :tcp_protocol_handler, """
  require Logger
  defmodule <%= @mod %>.TcpProtocolHander do
    def start_link(ref, socket, transport, opts \\\\ []) do
      :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
    end

    def init(ref, socket, transport, opts \\\\ []) do
      :erlang.process_flag(:trap_exit, true)
      :ok = :proc_lib.init_ack({:ok, self()})
      :ok = :ranch.accept_ack(ref)
      :ok = transport.setopts(socket, [{:active, :once}])
      state = %{
        socket: socket,
        transport: transport
      }
      :gen_server.enter_loop(__MODULE__, [], state)
    end

    def handle_info({:tcp, _socket, data}, %{socket: socket,transport: transport} = state) do
      :ok = transport.setopts(socket, [{:active, :once}])
      # Do something
    end

    def handle_info({:tcp_closed, _socket}, state) do
      Logger.warn "Connection closed by client socket = \#{inspect state.socket}."
      {:stop, :normal, state}
    end

    def handle_info(:timeout, state) do
      {:noreply, state}
    end

    def handle_info({:tcp_error, _socket, reason}, state) do
      :ok = state.transport.close(state.socket)
      {:stop, state}
    end

    def handle_info({:'EXIT', pid, reason}, state) do
      {:noreply, state}
    end

    def terminate(reason, state) do
      :ok
    end

    def code_change(_old_vsn, state, _extra) do
      {:ok, state}
    end
  end
  """

  embed_template :lib_sup, """
  defmodule <%= @mod %> do
    use Application
    def start(_type, _args) do
      import Supervisor.Spec, warn: false
      children = [
        worker(<%= @mod %>.TcpAcceptor, []),
      ]
      opts = [strategy: :one_for_one, name: <%= @mod %>.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  """

  embed_template :test, """
  defmodule <%= @mod %>Test do
    use ExUnit.Case
    doctest <%= @mod %>

    test "the truth" do
      assert 1 + 1 == 2
    end
  end
  """

  embed_template :test_helper, """
  ExUnit.start()
  """
end