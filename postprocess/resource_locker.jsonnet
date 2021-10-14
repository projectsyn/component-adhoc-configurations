/**
 * Convenience helpers for ResourceLocker objects
 * Inject namespace of resourcelocker operator (extracted from parameters.resource_locker)
 * Inject serviceaccount ref (extracted from parameters.adhoc_configurations)
 */

local com = import 'lib/commodore.libjsonnet';
local inv = com.inventory();
local rl =
  if std.length(std.find('resource-locker', inv.applications)) > 0 then
    import 'lib/resource-locker.libjsonnet'
  else
    error |||
      adhoc-configurations: To apply patches to existing objects on the
      cluster the resource-locker component must be enabled for the cluster
    |||;
local namespace = inv.parameters.resource_locker.namespace;
local params = inv.parameters.adhoc_configurations;
local serviceaccountname = params.resourcelocker.serviceaccount.name;

// Extract resource locker chart version to pass to the resource-locker
// component library's `formatPatch()`.
// NOTE: Ideally Commodore would allow component libraries to identify whether
// they're used during compilation or postprocessing. However, this is
// currently not possible, since Jsonnet doesn't support checking if an
// external variable is set/valid.
local rl_params =
  if std.objectHas(inv.parameters, 'resource_locker') then
    inv.parameters.resource_locker
  else
    {};
local rl_version =
  if std.objectHas(rl_params, 'charts') then
    rl_params.charts['resource-locker-operator'];

local manifests_dir = std.extVar('output_path');

local list_dir(dir, basename=true) =
  std.native('list_dir')(dir, basename);

local manifests_files = list_dir(manifests_dir);

local input_file(elem) = manifests_dir + '/' + elem;
local stem(elem) =
  local elems = std.split(elem, '.');
  std.join('.', elems[:std.length(elems) - 1]);

local patch(obj) =
  local prefixed_name =
    if std.startsWith(obj.metadata.name, 'adhoc-configurations') then
      obj.metadata.name
    else
      'adhoc-configurations-%s' % obj.metadata.name;
  obj {
    apiVersion: rl.apiVersion,
    metadata+: {
      name: prefixed_name,
      namespace: namespace,
    },
    spec+: {
      [if std.objectHas(obj.spec, 'patches') then 'patches']:
        std.mapWithIndex(
          function(idx, elem) rl.renderPatch(elem, rl_version, 'patch%d' % idx),
          super.patches
        ),
      serviceAccountRef: {
        name: serviceaccountname,
      },
    },
  };

local fixup_obj(obj) =
  if obj.kind == 'ResourceLocker' then
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

local output = {
  [stem(elem)]: fixup(input_file(elem))
  for elem in manifests_files
};

{
  [fn]: output[fn]
  for fn in std.objectFields(output)
  if output[fn] != null
}
