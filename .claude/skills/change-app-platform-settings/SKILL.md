---
name: change-app-platform-settings
description: Safely change settings of an existing App Platform app (env vars, tariff/preset, branch, health check, build command, auto-deploy) for rangauto.ru, the Telegram bot or centro-plus.ru. Use for any edit to a restapi_object in terraform/.
---

# Change App Platform settings safely

All apps are production and an apply to `main` is automatic. Do the change in a branch and never apply locally.

## 1. Understand how the resource applies changes
- Identify the resource: `rangauto_test` (live rangauto.ru, 289117), `bot` (289399), `potolki` (centro-plus.ru).
- Only `update_data` is sent on update (PATCH). If the setting exists only in `data`, it applies at creation and is
  ignored afterwards (`ignore_changes = [data]`, `ignore_all_server_changes = true`). So: add it to `update_data`.
- Not changeable via PATCH: `branch_name` on an existing app (Timeweb applies it only at creation),
  `type`, `language`, `framework`, repository, location. Changing these means recreating the app: stop and ask the user.
- `envs` in `update_data` REPLACE the whole set: variables added by hand in the panel are removed. Before changing envs,
  ask the user to confirm nothing is set only in the panel; keep every variable the site code reads.
- Empty-string values are filtered out of env maps; setting a secret to "" removes the variable.

## 2. Make the change
- Env vars: add to the `*_envs` local. Secrets go through `variables.tf` (`sensitive = true`) -> `terraform.yml`
  (`TF_VAR_*`) -> README table; never literals. The site repo must read the same name (see CLAUDE.md, "Link to the site repositories").
- Preset: it changes the monthly bill (rangauto.ru 510 RUB/month on `preset_backend_1gb`, others cheapest in location).
  State the old and new price to the user. Presets are location-specific.
- Health check: a wrong path makes every deploy fail. Confirm the path returns 200 in the site repo.
- Build/run commands: confirm against the site repo's Dockerfile or build script.
- Keep comments in Russian, run `terraform fmt`.

## 3. Verify
1. `terraform fmt -check -recursive` and `terraform validate`.
2. Run the `plan-analyst` agent. Expected: exactly one `update in-place` for the intended resource and nothing else.
   Anything with destroy, `must be replaced` or `-/+` is a stop. An update on another resource is a stop.
3. Run the `infra-reviewer` agent on the diff.
4. Run the `prod-apply-checklist` skill before merging.
5. After the apply: Actions -> "App Platform" -> `status` (and `logs`) for the app id; the deploy must be successful
   and the health check green. A setting change may trigger a redeploy: expect brief downtime for a single-instance backend.

## Rollback
Revert the commit and merge; the next apply restores the previous settings. For a bad deploy of the site code itself use
Actions -> "App Platform" -> `redeploy` or `reboot`. Never edit the Terraform state by hand without asking the user.
