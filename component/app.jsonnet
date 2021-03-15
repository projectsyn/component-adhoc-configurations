local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.adhoc_configurations;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('adhoc-configurations', params.namespace);

{
  'adhoc-configurations': app,
}
