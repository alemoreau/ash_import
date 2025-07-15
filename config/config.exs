import Config

config :ash_import, test: true

config :ash_import, ecto_repos: [AshImport.Test.Repo]
config :logger, level: :warning

if Mix.env() == :dev do
  config :git_ops,
    mix_project: AshImport.MixProject,
    github_handle_lookup?: true,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/alemoreau/ash_import",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: [
      "README.md",
      "documentation/tutorials/getting-started-with-ash-import.md"
    ],
    version_tag_prefix: "v"
end

if Mix.env() == :test do
  config :ash_import, :oban,
    testing: :manual,
    repo: AshImport.Test.Repo,
    prefix: "private",
    plugins: [
      {Oban.Plugins.Cron, []}
    ],
    queues: [
      triggered_process: 10,
      triggered_process_2: 10,
      triggered_say_hello: 10,
      triggered_tenant_aware: 10,
      triggered_process_generic: 10,
      triggered_fail_oban_job: 10
    ]

  config :ash_import, AshImport.Test.Repo,
    username: "postgres",
    # sobelow_skip ["Config.Secrets"]
    password: "postgres",
    database: "ash_import_test",
    hostname: "db",
    pool: Ecto.Adapters.SQL.Sandbox

  config :ash, :validate_domain_resource_inclusion?, false
end
