local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.adhoc_configurations;
local argocd = import 'lib/argocd.libjsonnet';

// We target the App at the default namespace with the understanding that
// manifests should always be be namespaced
local app = argocd.App('adhoc-configurations', 'default') {
  spec+: {
    syncPolicy+: {
      syncOptions+: [
        'ServerSideApply=true',
      ],
    },
    ignoreDifferences:
      // This completely ignores the keys in the parameter, since we only use
      // a dictionary over a list to allow users to edit existing entries in
      // the hierarchy.
      // We also allow users to disable already configured diff customizations
      // by setting the corresponding entry's value to `null`.
      std.filter(
        function(it) it != null,
        std.objectValues(params.argocd_ignore_differences)
      ),
  },
};

local appPath =
  local project = std.get(std.get(app, 'spec', {}), 'project', 'syn');
  if project == 'syn' then 'apps' else 'apps-%s' % project;

{
  ['%s/adhoc-configurations' % appPath]: app,
}
