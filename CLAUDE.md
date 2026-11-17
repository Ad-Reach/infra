# CLAUDE.md

Terraform for the Ad-Reach client sites hosted on Timeweb Cloud App Platform.
There are no servers (VDS) and no CMS: site content lives in the site repositories.
README.md (Russian) has the operator docs: secrets table, DNS records, costs. Keep it in sync.

## Repository map

```
terraform/
  versions.tf   providers (restapi 2.0.1 pinned, http, random), S3 backend, restapi provider config
  variables.tf  all inputs; secrets are sensitive = true, default ""
  apps.tf       shared locals (VCS ids, presets, cars_envs), data sources, rangauto.ru and centro-plus.ru apps
  bot.tf        Telegram lead bot app (cars/bot), its deploy-log data sources and outputs
  imports.tf    removed {} blocks for resources deleted by hand
  outputs.tf    potolki / rangauto_test outputs
.github/workflows/
  terraform.yml fmt -check, init, validate, plan; apply only on non-PR events
  app.yml       manual status / logs / reboot / redeploy of one App Platform app via the Timeweb API
.claude/agents/ infra-reviewer, plan-analyst
.claude/skills/ add-client-site, change-app-platform-settings, prod-apply-checklist
```

The Timeweb Terraform provider cannot manage App Platform, so apps are `restapi_object`
resources over the Timeweb REST API (https://timeweb.cloud/api-docs), not first-class resources.

## Environments (there is exactly one, and it is prod)

One Terraform state (`rangauto-tfstate` bucket, key `infra/terraform.tfstate`, Timeweb S3).
No dev/staging workspace exists. Every resource below is production:

| Resource | App | App ID | Location |
|---|---|---|---|
| `restapi_object.rangauto_test` | rangauto.ru (live site, repo `Ad-Reach/cars`, branch `main`) | 289117 | ru-3 Moscow |
| `restapi_object.bot` | bot.rangauto.ru (Telegram lead bot, `cars/bot`, Mini App at tg.rangauto.ru) | 289399 | nl-1 Amsterdam |
| `restapi_object.potolki` | centro-plus.ru (static site, repo `Ad-Reach/potolki`, `dist/`) | see `terraform output potolki` | ru-3 Moscow |

- `rangauto_test` is a legacy name for the live rangauto.ru app. Never rename it without a `moved` block:
  a rename is destroy + create, which deletes the live site.
- `catalog.rangauto.ru` is on a separate server and out of scope. Do not touch it.
- Sites are in ru-3 because App Platform's foreign IPs are blocked from Russia. The bot is in nl-1
  because Telegram API is unreachable from Moscow. Do not move either without a reason.
- `potolki_enabled = false` or `bot_enabled = false` destroys that app (count goes to 0). Never flip them casually.

## Safe-work order (mandatory)

1. Edit `.tf` files. Never run `terraform apply` or `destroy` locally, and never `-auto-approve`.
2. `terraform fmt -check -recursive` and `terraform validate`.
3. `terraform plan` (CI does this on the PR; see "Running checks"). Read it fully.
4. Run the `infra-reviewer` agent on the diff, and `plan-analyst` to summarize a long plan.
5. Open a PR. Plan appears in the GitHub Actions run summary.
6. Merge to `main` only after the `prod-apply-checklist` skill passes. A push to `main` that touches
   `terraform/**` or the workflow applies to prod automatically, with no further approval.
7. After apply, check deploy status (`terraform output`, or Actions -> "App Platform" -> status).

Stop and ask the user before: any plan line with `destroy`, `must be replaced` or `-/+`; any change of
`type`, `language`, `framework`, `provider_id`, `repository_id`, `location`/preset; flipping `*_enabled`;
editing state (`terraform state`, `import`, `removed`, `moved`); anything touching DNS or domains.

Note: `workflow_dispatch` on terraform.yml applies from whatever branch is selected. Do not trigger it
from a feature branch.

## Running checks

Local `terraform` may not be installed. Without credentials you can still do the static checks:

```bash
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

A real plan needs the state backend and the API token (never commit or echo them):

```bash
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... TF_VAR_twc_token=... TF_VAR_smtp_pass=...
terraform init && terraform plan -no-color -lock=false
```

`smtp_pass` has a validation and must be non-empty. CI passes all secrets from GitHub Actions (see README).
`backend_override.tf`, `*.tfstate`, `*.tfplan` are gitignored; never commit them.
Terraform version in CI: 1.10.3 (`required_version >= 1.10`). Provider lock file is committed.

## Conventions

- Comments and README are in Russian; this file and `.claude/` are in English. Match the language of the file you edit.
- Every app is a `restapi_object` with the same shape: `path`/`create_path` (`/api/v2/apps`)/`read_path`/
  `update_path`/`destroy_path`, `update_method = "PATCH"`, `ignore_all_server_changes = true`.
- `data` is the create-time payload (contains a commit SHA that changes on every push), so apps that use
  `lifecycle { ignore_changes = [data] }` change only through `update_data`. Put runtime settings in
  `update_data`, otherwise they never apply. `potolki` does not ignore `data` yet; check its plan carefully.
- Timeweb ignores `branch_name` in PATCH for an existing app: it applies only at creation.
- `update_data` envs replace all env vars: anything set by hand in the panel is overwritten.
- Per-site toggles: `<site>_enabled`, `<site>_repo`, `<site>_location`, `<site>_branch`; resources use `count`.
- Tariffs are picked by API as the cheapest preset in a location (see `potolki_presets`, `bot_presets`).
  Rangauto.ru uses fixed `preset_backend_1gb` (510 RUB/month); changing a preset changes the bill.
- Env maps use `{ for k, v in {...} : k => v if v != "" }` so empty secrets are omitted.
- Secrets: only via `variable ... sensitive = true` fed from GitHub Actions secrets (`TF_VAR_*` in terraform.yml).
  Never hardcode tokens, passwords, keys, chat ids or proxy URLs in `.tf`, README or commits.
  Known debt: `NEW_CARS_PREVIEW_KEY` is a literal in `apps.tf` (`cars_envs`); move it to a secret rather than copy the pattern.
- Add a new secret in three places: `variables.tf`, `terraform.yml` env, README secrets table.
- Run `terraform fmt` before committing; CI fails on unformatted code.
- Keep changes idempotent: no `timestamp()`, `uuid()`, or `count` that depends on values known only after apply
  (see the comment in `bot.tf`; this has already broken a deploy once).

## Link to the site repositories

- `Ad-Reach/cars`: rangauto.ru (root, branch `main`) and the bot (`/bot` folder, `bot/Dockerfile`).
  Both use the same GitHub repo id (`local.repo_cars`) through the "Ad-Reach" GitHub provider in App Platform.
- `Ad-Reach/potolki`: centro-plus.ru; ships a prebuilt `dist/` (its CI checks it matches sources).
- Deploys of site code are NOT done from this repo: a push to the site repo's branch makes App Platform
  rebuild by itself (`is_auto_deploy = true`). This repo owns only the app definition, env vars and tariff.
- App Platform can see only repos the Timeweb Cloud GitHub App was granted access to (org Ad-Reach settings).
- Domains are added in the Timeweb panel and DNS is edited by hand at reg.ru. Neither is in Terraform.
- Env vars the site code reads (SMTP_*, TELEGRAM_*, LEAD_EMAIL_TO, CHATS_S3_*) are defined here: renaming one
  here breaks the site until its repo is changed too. Change both sides together.

## Skills and agents

- `add-client-site`: add a new client site, modelled on `potolki`.
- `change-app-platform-settings`: change env/preset/branch/health check of an existing app safely.
- `prod-apply-checklist`: run before merging anything under `terraform/` into `main`.
- `infra-reviewer` (read-only, sonnet): review a diff. `plan-analyst` (haiku): run plan and report only the essence.
