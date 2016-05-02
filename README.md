# ExRanchServerTasks

How to use these tasks

```
git clone https://github.com/developerworks/ex_ranch_server_tasks.git
cd ex_ranch_server_tasks
mix archive.build
mix archive.install
```

and create your rand server project like:

```
mix ranch.new a111
* creating README.md
* creating .gitignore
* creating .editorconfig
* creating mix.exs
* creating config
* creating config/config.exs
* creating config/dev.exs
* creating config/prod.exs
* creating config/test.exs
* creating lib
* creating lib/a111
* creating lib/a111/ssl_acceptor.ex
* creating lib/a111/tcp_acceptor.ex
* creating lib/a111/ssl_protocol_handler.ex
* creating lib/a111/tcp_protocol_handler.ex
* creating lib/a111.ex
* creating test
* creating test/test_helper.exs
* creating test/a111_test.exs
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add ex_ranch_server_tasks to your list of dependencies in `mix.exs`:

        def deps do
          [{:ex_ranch_server_tasks, "~> 0.0.1"}]
        end

  2. Ensure ex_ranch_server_tasks is started before your application:

        def application do
          [applications: [:ex_ranch_server_tasks]]
        end

## TODO

- [x] Generate ssl and tcp acceptor
- [x] Generate ssl and tcp protocol hander
- [ ] Generate ssl certificate and certificate configs
