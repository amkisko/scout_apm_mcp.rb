# Archival cleanup

## Participants

Andrei Makarov

## Decisions

Stay on main. Do not open a patch or feature branch for this pass.

Skip a 0.2.1 gem cut. Published RubyGems and GitHub release remain 0.2.0. Commits after tag 0.2.0 are pray, documentation, and lockfile refresh. The gemspec has no json runtime dependency. CVE-2026-71847 stays not_affected for this execute path.

Close leftover GitHub issue 6. Bitwarden and KeePassXC CLI support will not ship. Existing 1Password, opdotenv, and environment-variable credential paths remain.

Do not archive GitHub, GitLab, or Codeberg until the operator asks.

## Effects

GitHub issue 6 Bitwarden and KeePassXC CLI support is closed.

Local leftover dependabot branches were deleted. Local heads are only main. GitHub remote heads were only main.

README Status already names scout-cli for new ScoutAPM CLI and automation work.

GitHub archive is not done in this pass.

## Next

Archive GitHub when the operator asks. GitLab and Codeberg archive wait for the same ask.

No 0.2.1 gem, tag, or GitHub release unless a later product change needs one.

## Source

usr/docs/issues/20260907141000_engineering-and-dependency-audit.md
usr/docs/changelogs/20260907141000_advisory-lockfile-refresh.md
usr/docs/dependencies/20260907141000_json-cve-2026-71847.md
https://github.com/amkisko/scout_apm_mcp.rb/issues/6
https://github.com/amkisko/scout_apm_mcp.rb
https://github.com/amkisko/scout-cli.rs
https://rubygems.org/gems/scout_apm_mcp
