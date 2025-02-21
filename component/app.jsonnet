local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.adhoc_configurations;
local argocd = import 'lib/argocd.libjsonnet';

local instance = inv.parameters._instance;

local validate_config(app) =
  local default_manifests_path = 'manifests/%s' % inv.parameters.cluster.name;
  if inv.parameters._instance != 'adhoc-configurations' &&
     params.manifests_path == default_manifests_path then
    error
      'manifests path `%s` is reserved ' % default_manifests_path +
      'for the unaliased `adhoc-configurations` component'
  else
    app;

// We target the App at the default namespace with the understanding that
// manifests should always be be namespaced
local app = argocd.App(instance, 'default', base='adhoc-configurations') {
  spec+: {
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
  ['%s/%s' % [ appPath, instance ]]: validate_config(app),
}
