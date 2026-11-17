---
name: prod-apply-checklist
description: Checklist to run before merging any change under terraform/ or .github/workflows/terraform.yml into main, because a push to main applies to production automatically. Use before merge, before triggering the Terraform workflow, or when asked whether a change is safe to apply.
---

# Pre-apply checklist (production)

There is one environment and it is production. Merge to `main` = `terraform apply` with the saved plan, no approval step.
Go through every item; report each as PASS / FAIL / N/A with one line of evidence. Any FAIL stops the merge.

## Code
- [ ] `terraform fmt -check -recursive` passes.
- [ ] `terraform init -backend=false && terraform validate` passes (CI also runs both).
- [ ] No literal secrets in the diff (tokens, passwords, keys, chat ids, proxy URLs). Search the diff, README and workflows.
- [ ] New secrets exist in all three places: `variables.tf` (`sensitive`), `terraform.yml` env, README table,
      and the user confirmed the GitHub Actions secret is created.
- [ ] `infra-reviewer` returned `OK` (or only NOTEs the user accepted).

## Plan
- [ ] A fresh plan exists for this exact commit (PR run summary or `plan-analyst`). It was read, not skimmed.
- [ ] Plan contains no `destroy`, `must be replaced` or `-/+`. If it does, the user explicitly approved each one by name.
- [ ] Only the intended resources change; no update on unrelated apps. Known: `potolki` may show an update per new commit.
- [ ] No unintended env var removal on `rangauto_test`, `bot`, `potolki` (PATCH replaces all envs; panel-only vars are lost).
- [ ] No preset/tariff change, or the new monthly cost was stated to the user and accepted.
- [ ] No `*_enabled` flag switched to false, no `count` change on existing apps.
- [ ] State changes (`removed`, `moved`, imports) are intended and reviewed.

## Timing and blast radius
- [ ] The change touches Terraform only; site code deploys happen from the site repos, not here.
- [ ] A redeploy of the live site (rangauto.ru) or the bot lead intake is acceptable now: the user chose a moment,
      not in the middle of an ad campaign peak.
- [ ] No other Terraform run is in progress (workflow concurrency group `terraform` serializes, but check Actions).
- [ ] The apply will come from `main` via push, not from `workflow_dispatch` on a feature branch.

## After the apply
- [ ] The workflow's Apply and Outputs steps are green.
- [ ] Actions -> "App Platform" -> `status` for each touched app: deploy status is success, `commit_sha` as expected.
- [ ] Open the site / send a test lead if lead intake, SMTP or Telegram envs changed.
- [ ] README is in sync (table of sites, DNS, secrets, costs).

## Rollback plan (state it before merging)
Revert commit + merge. For a failed deploy of the site code: App Platform workflow `redeploy`/`reboot`. If an app was
destroyed by mistake: stop, do not re-apply blindly (a new app gets a new id, IP and needs DNS and domains redone); ask the user.
