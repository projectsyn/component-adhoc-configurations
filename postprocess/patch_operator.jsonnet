/**
 * Convenience helpers for Patch objects
 * Inject namespace of patch-operator (extracted from parameters.patch_operator)
 * Inject serviceaccount ref (extracted from parameters.adhoc_configurations)
 */

local com = import 'lib/commodore.libjsonnet';
local inv = com.inventory();

local po =
  if std.length(std.find('patch-operator', inv.applications)) > 0 then
    import 'lib/patch-operator.libsonnet'
  else
    error |||
      adhoc-configurations: To apply patches to existing objects on the
      cluster the patch-operator component must be enabled for the cluster
    |||;

local namespace = inv.parameters.patch_operator.namespace;
local params = inv.parameters.adhoc_configurations;
local serviceaccountname =
  local patches_params =
    local newparams = inv.parameters.adhoc_configurations.patches;
    if std.objectHas(inv.parameters.adhoc_configurations, 'resourcelocker') then
      newparams + com.makeMergeable(
        std.trace(
          'Parameter `resourcelocker` is deprecated, please migrate your config to pararmeter `patches`.',
          inv.parameters.adhoc_configurations.resourcelocker
        )
      )
    else
      newparams;
  patches_params.serviceaccount.name;

local manifests_dir = std.extVar('output_path');

local patch(obj) =
  local prefixed_name =
    if std.startsWith(obj.metadata.name, 'adhoc-configurations') then
      obj.metadata.name
    else
      'adhoc-configurations-%s' % obj.metadata.name;
  if std.objectHas(obj.spec, 'resources') then
    error |||
      Component adhoc-configurations doesn't support ResourceLocker objects which lock full resources anymore.
      Please change resource '%s' into a regular ad-hoc manifest and let ArgoCD perform the reconciliation directly.
    ||| % obj.metadata.name
  else
    obj {
      apiVersion: po.apiVersion,
      [if obj.kind != 'Patch' then 'kind']: std.trace(
        'Transforming %s %s into Patch' % [ obj.kind, obj.metadata.name ],
        'Patch'
      ),
      metadata+: {
        name: prefixed_name,
        namespace: namespace,
        annotations+: {
          'argocd.argoproj.io/sync-options': 'SkipDryRunOnMissingResource=true',
        },
      },
      spec+: {
        [if std.objectHas(obj.spec, 'patches') then 'patches']:
          local res =
            if std.isArray(super.patches) then
              std.foldl(
                function(obj, p)
                  local idx = obj.idx + 1;
                  local pid = std.get(p, 'id', 'patch%d' % idx);
                  obj {
                    idx: idx,
                    patches+: {
                      [pid]: p { id:: '' },
                    },
                  },
                super.patches,
                { idx: 0, patches: {} }
              )
            else
              local patches = super.patches;
              // we assume that patches is already compatible with patch-operator,
              // if it isn't an array.
              { patches: patches };
          res.patches,
        serviceAccountRef: {
          name: serviceaccountname,
        },
      },
    };

local fixup_obj(obj) =
  if std.member([ 'ResourceLocker', 'Patch' ], obj.kind) then
    { obj: patch(obj), required: true }
  else
    { obj: obj, required: false };

local fixup(obj_file) =
  local objs = std.filter(function(it) it != null, com.yaml_load_all(obj_file));
  // process all objs
  local fixed_up_objs = [ fixup_obj(obj) for obj in objs ];
  local fixed_up = std.foldl(
    function(a, elem) a {
      contents+: [ elem.obj ],
      required: a.required || elem.required,
    },
    fixed_up_objs,
    {
      contents: [],
      required: false,
    }
  );

  if fixed_up.required then fixed_up.contents;

local stem(elem) =
  local elems = std.split(elem, '.');
  std.join('.', elems[:std.length(elems) - 1]);

local output = {
  local input_file(elem) = manifests_dir + '/' + elem,
  [stem(elem)]: fixup(input_file(elem))
  for elem in com.list_dir(manifests_dir)
};

{
  [fn]: output[fn]
  for fn in std.objectFields(output)
  if output[fn] != null
}
