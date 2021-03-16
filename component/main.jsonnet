local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local rl_config = inv.parameters.adhoc_configurations.resourcelocker;
local sa_namespace =
  if rl_config.serviceaccount.namespace != null then
    rl_config.serviceaccount.namespace
  else
    inv.parameters.resource_locker.namespace;

local config_error =
  !rl_config.create_serviceaccount &&
  rl_config.serviceaccount.namespace == null;

local serviceaccount =
  if config_error then (
    error |||
      Parameter `resourcelocker.serviceaccount.namespace` must be non-null
      when parameter `resourcelocker.create_serviceaccount` is False.
    |||
  ) else (
    if rl_config.create_serviceaccount then
      kube.ServiceAccount(rl_config.serviceaccount.name) {
        metadata+: {
          namespace: sa_namespace,
        },
      }
    else
      null
  );

local clusterrolebinding = kube.ClusterRoleBinding('adhoc-configurations-manager') {
  subjects_: [ serviceaccount ],
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: rl_config.clusterrole_name,
  },
};

local rbac = std.filter(function(it) it != null, [
  serviceaccount,
  if rl_config.create_clusterrolebinding then clusterrolebinding,
]);


{
  [if std.length(rbac) > 0 then '00_resource_locker_rbac']: rbac,
}
