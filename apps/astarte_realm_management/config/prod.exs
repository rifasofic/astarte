use Mix.Config

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST"), System.get_env("CASSANDRA_DB_PORT")}]

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [
    :realm,
    :module,
    :function,
    :tag
  ],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
