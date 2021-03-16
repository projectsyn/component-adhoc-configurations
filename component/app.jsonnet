local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.adhoc_configurations;
local argocd = import 'lib/argocd.libjsonnet';

// We target the App at the default namespace with the understanding that
// manifests should always be be namespaced
local app = argocd.App('adhoc-configurations', 'default');

{
  'adhoc-configurations': app,
}
