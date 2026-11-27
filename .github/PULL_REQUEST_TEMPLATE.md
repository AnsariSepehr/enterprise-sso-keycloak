## What changed
## Which service / phase
## Checklist
- [ ] `bash tests/run-tests.sh` is green (it includes ShellCheck, template rendering, the link check and `scripts/tools/check-secrets.sh`)
- [ ] Only placeholders (`example.corp`, `<PASSWORD>`, `<SSO_IP>` ...) appear
- [ ] Anything that is not yet verified is labelled as such
- [ ] Bugs hit and workarounds used are added to `docs/troubleshooting.md` / `docs/post-install-changes.md`
- [ ] A new break-glass path (or a service without one) is recorded in `docs/break-glass.md`
- [ ] A tool that edits files has a fixture test in `tests/`
