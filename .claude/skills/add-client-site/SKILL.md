---
name: add-client-site
description: Add a new client website (a new App Platform app) to this Terraform repo, modelled on centro-plus.ru (potolki). Use when asked to onboard, connect or deploy a new site, or to add a repo to the infrastructure.
disable-model-invocation: true
---

# Add a new client site

Everything here is production: there is no staging state. Work on a branch, never apply locally.
Ask the user first (do not guess): site domain, GitHub repo (`Ad-Reach/<name>`), branch, static (`frontend`)
or server (`backend`, Docker), location (default `ru-3`; foreign IPs are blocked from Russia), build command and output dir,
env vars and which of them are secrets.

## Prerequisites outside Terraform (tell the user; they must do them)
1. The Timeweb Cloud GitHub App must have access to the repo (org Ad-Reach -> Settings -> GitHub Apps).
   Without it the precondition `repo_<name> != null` fails the plan.
2. After apply: add the domain and `www.` in the panel (app -> Domains), then create the DNS `A` records at reg.ru.

## Steps
1. Read `terraform/apps.tf` (`potolki` is the template for static, `bot.tf` for Docker backend) and `variables.tf`.
2. `variables.tf`: add a section `# --- <domain> (Ad-Reach/<repo>) ---` with `<site>_enabled` (bool),
   `<site>_repo`, `<site>_location`, `<site>_branch`, plus a `sensitive = true` variable (default `""`) for each secret.
3. Add the code. Prefer a new file `terraform/<site>.tf` for a new site, mirroring `bot.tf`. It needs:
   - `data "http"` for the repo list, presets (`/api/v1/presets/apps`, `frontend_presets` or `backend_presets`) and the branch head
     (`.../repository/<id>/branch?name=...`), all with `count = var.<site>_enabled ? 1 : 0` and `status_code == 200` postconditions.
   - locals: repo id by `lower(full_name)`, cheapest preset in the location, head commit sha.
   - `restapi_object.<site>` with the standard shape (see CLAUDE.md): `data` for creation, `update_data` for later changes,
     `ignore_all_server_changes = true`, and `lifecycle { ignore_changes = [data] }` (the commit SHA in `data` changes on every push).
     Preconditions for repo and preset not being null.
   - Env map with `{ for k, v in {...} : k => v if v != "" }`. No literal secrets.
   - An output (`id`, `ip`, `domains`, preset) like `output "bot"`; mark anything secret `sensitive`.
4. For each new secret: `terraform.yml` env `TF_VAR_<name>: ${{ secrets.<NAME> }}`, and a row in the README secrets table.
   Tell the user to create the GitHub secret before merging, because the apply runs on merge.
5. README (Russian): add the site to the top table, the DNS table, and the cost section.
6. Do not reuse names of existing resources and do not touch `rangauto_test`, `bot`, `potolki`.
7. Validate: `terraform fmt -recursive`, `terraform init -backend=false`, `terraform validate`.
8. Run the `plan-analyst` agent. The plan must contain only `+ create` for new resources (and new data sources/outputs):
   if anything existing changes or is destroyed, stop and fix.
9. Run the `infra-reviewer` agent, fix BLOCK/WARN findings, then go through the `prod-apply-checklist` skill.
10. Open a PR (only if the user asked). After merge, check the deploy: Actions -> App Platform -> status for the new app id.

## Pitfalls
- Branch is fixed at creation: Timeweb ignores `branch_name` in PATCH. Make sure the branch is right before the first apply.
- `count` must depend only on the `*_enabled` flag, never on API responses.
- If the plan shows new data sources failing with a non-200 status, the token or repo access is the problem, not the code.
