local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.adhoc_configurations;

local patch_config =
  local patches = params.patches;
  if std.objectHas(params, 'resourcelocker') then
    patches + com.makeMergeable(
      std.trace(
        'Parameter `resourcelocker` is deprecated, please migrate your config to pararmeter `patches`.',
        params.resourcelocker
      )
    )
  else
    patches;

local sa_config = patch_config.serviceaccount;
local cr_config = patch_config.clusterrolebinding;
local sa_namespace =
  if std.length(std.find('patch-operator', inv.applications)) > 0 then
    inv.parameters.patch_operator.namespace
  else
    error 'adhoc_configurations: object patches require component patch-operator';

local serviceaccount = kube.ServiceAccount(sa_config.name) {
  metadata+: {
    namespace: sa_namespace,
  },
};

local clusterrolebinding = kube.ClusterRoleBinding('adhoc-configurations-manager') {
  subjects_: [ serviceaccount ],
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: cr_config.clusterrole_name,
  },
};

local rbac = std.filter(function(it) it != null, [
  if sa_config.create then serviceaccount,
  if cr_config.create then clusterrolebinding,
]);


{
  [if std.length(rbac) > 0 then '00_patch_operator_rbac']: rbac,
}
