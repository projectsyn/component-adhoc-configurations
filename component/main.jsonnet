local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local rl_config = inv.parameters.adhoc_configurations.resourcelocker;
local sa_config = rl_config.serviceaccount;
local cr_config = rl_config.clusterrolebinding;
local sa_namespace =
  if std.length(std.find('resource-locker', inv.applications)) > 0 then
    inv.parameters.resource_locker.namespace
  else
    error 'adhoc_configurations: object patches require component resource-locker';

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
  [if std.length(rbac) > 0 then '00_resource_locker_rbac']: rbac,
}
