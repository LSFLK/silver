## Plan: Minimal Postfix Helm Bring-up

Bring up Postfix in Kubernetes with the least complexity by reusing existing Postfix configs (main.cf, master.cf), embedding them into the chart, and validating pod/service startup first before integrating Raven/OpenDKIM/RSPAMD.

**Steps**
1. Baseline chart alignment: update chart metadata and defaults so Postfix (not nginx/http) is the deployed workload. Set image to silver-smtp, disable HTTP-centric behavior, and set minimal safe defaults for a first startup. 
2. Phase 1 - Config embedding (*depends on 1*): create ConfigMap templates that package old-config/postfix/main.cf and old-config/postfix/master.cf into the release.
3. Phase 1 - Deployment wiring (*depends on 2*): update deployment template to mount the two config files at /etc/postfix/main.cf and /etc/postfix/master.cf, set SMTP ports (25, 587), and inject minimal env vars required by the container startup.
4. Phase 1 - Service wiring (*parallel with 3*): update service template to expose ports 25 and 587 as ClusterIP and remove HTTP naming assumptions.
5. Phase 2 - Optional legacy compatibility (*depends on 3*): inspect old-manifests-only mounts/env and add only what is strictly required to avoid crashloop in standalone mode; defer dependency endpoints (Raven/OpenDKIM/RSPAMD) until first boot is verified.
6. Phase 3 - Parent chart integration (*depends on 3 and 4*): register postfix as a dependency in the umbrella chart and expose a postfix.enabled flag with conservative defaults.
7. Phase 4 - Render and smoke validation (*depends on 6*): helm lint + helm template + install/upgrade in a dev namespace; verify pod reaches Running and service exposes 25/587 internally.
8. Phase 4 - Runtime checks (*depends on 7*): validate Postfix process in logs, config file presence in container, and SMTP socket readiness from inside cluster.
9. Follow-up integration path (explicitly deferred): add Raven/OpenDKIM/RSPAMD service endpoints and TLS/cert mounts only after standalone startup is stable.

**Relevant files**
- /Users/maneesha/work/silver/charts/silver/charts/postfix/values.yaml - switch from helm-create defaults to Postfix runtime values (image, ports, env, mounts).
- /Users/maneesha/work/silver/charts/silver/charts/postfix/templates/deployment.yaml - remove/avoid HTTP assumptions, set SMTP container ports, add env/mounts.
- /Users/maneesha/work/silver/charts/silver/charts/postfix/templates/service.yaml - expose smtp/submission ports via ClusterIP.
- /Users/maneesha/work/silver/charts/silver/charts/postfix/templates/configmap-postfix.yaml (new) - embed main.cf and master.cf from old-config.
- /Users/maneesha/work/silver/charts/silver/charts/postfix/old-config/postfix/main.cf - source of truth for first-pass Postfix config.
- /Users/maneesha/work/silver/charts/silver/charts/postfix/old-config/postfix/master.cf - source of truth for first-pass Postfix process config.
- /Users/maneesha/work/silver/charts/silver/Chart.yaml - add postfix dependency entry.
- /Users/maneesha/work/silver/charts/silver/values.yaml - add postfix.enabled and pass minimal overrides if needed.
- /Users/maneesha/work/silver/charts/silver/charts/postfix/old-manifests/postfix-deployment.yaml - reference for legacy env/volume behavior.
- /Users/maneesha/work/silver/charts/silver/charts/postfix/old-manifests/postfix-service.yaml - reference for legacy service ports.

**Verification**
1. Run helm lint for postfix chart and umbrella chart.
2. Run helm template for postfix and confirm rendered Deployment has container ports 25/587 and mounts for /etc/postfix/main.cf and /etc/postfix/master.cf.
3. Deploy to a test namespace and confirm pod reaches Running (no CrashLoopBackOff).
4. Check pod logs for Postfix startup success and absence of fatal config errors.
5. Exec into pod to verify mounted config files exist and match expected content.
6. Run an in-cluster SMTP connectivity check to service:25 and service:587.

**Decisions**
- Service type: ClusterIP for first bring-up.
- Dependencies: start Postfix standalone first.
- Config source: embed old-config files into Helm-managed ConfigMap(s).
- Included scope: startup-focused Helmization of Postfix only.
- Excluded scope: Raven/OpenDKIM/RSPAMD integration, certbot PVC strategy, external LB exposure, and production hardening.

**Further Considerations**
1. Probe strategy after first success: Option A disable probes initially; Option B add TCP socket probes on 25 later.
2. Persistence strategy for spool/logs: Option A emptyDir for dev simplicity; Option B PVC for durability.
3. External exposure later: Option A NodePort for local clusters; Option B LoadBalancer for cloud environments.