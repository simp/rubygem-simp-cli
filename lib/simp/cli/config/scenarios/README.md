# GENERAL INFORMATION
This is a bit complicated...The YAML files in this directory are used to
generate YAML strings that describe the decision trees appropriate for
configuring particular SIMP scenarios.  Specifically, each scenario_items.yaml
specifies a sequence of YAML fragments that, when combined, creates the
scenario's configuration decision tree YAML.  Each fragment (aka part) is
comprised of a sequence of Items, where

- each Item is a data Item or an action Item
- a data Item is used to ascertain a value, which, in turn can be used
  as branch point in the decision tree
- an action Items simply affects an action
- any Item can use the value(s) from one or more data Items that precede it
  in the tree.

# SCENARIO ITEMS YAML FORMAT
The scenario files are used to generate the YAML decision trees.  These
files must be named scenario_items.yaml and must contain 3 keys:

- name: name of the scenario
- description: description of the scenario
- includes: sequence of YAML fragments (parts) that will be concatenated
  to create the scenario's configuration, decision tree YAML.

Any element in the 'includes' sequence can itself have 0 or more
variable substitutions defined.  See simp_item.yaml and parts/ldap_setup
for an example of variable substitutions.

NOTE:

- Each part in the 'includes' must exist in the 'parts' sub-directory.
- Since many configuration Items have dependencies upon other Items, the
  parts must be listed in a fashion that satisfies these dependencies.
  Otherwise and Simp::Cli::Config::InternalError will be raised.
- Fragments are intended to provide a form of code reuse. So, apply
  the DRY principle, when you are creating/reworking scenarios.

# GENERATED YAML FILE FORMAT
This section describes the format of the generated, decision tree,
which necessarily also describes the format of the YAML fragments.

The format is:
```yaml
---
- ItemA
- ItemB:
  answer1:
  - ItemC modifier1
  - ItemD
  answer2:
  - ItemE
  - ItemF modifier2 modifier3:
     answer3:
     - ItemG
- ItemH
```

where modifiers, which are parsed as part of the YAML key, are
used to control specific behaviors of an Item.  The supported
modifiers are as follows:

- FILE=value   = set the Item's .file to value
- DRYRUNAPPLY  = make sure an ActionItem's apply() is called even when
                 the :dry_run option is selected
- NOAPPLY      = set an ActionItem's .skip_apply; ActionItem.apply()
                 will do nothing
- USERAPPLY    = execute an ActionItem's apply() even when running
                 as a non-privileged user
- SILENT       = set an Item's .silent; suppresses stdout console/log
                 output; This option is best used in conjuction with
                 SKIPQUERY for Items for which no user interaction is
                 required (i.e., Items for which internal logic can be
                 used to figure out their correct values).
- SKIPQUERY    = set the Item's .skip_query ; Item will use
                 .default_value_noninteractive() for value
- NOYAML       = set the Item's .skip_yaml ; no YAML for Item will be
                 written
- GENERATENOQUERY = set a PasswordItem's .generate_option to :generate_no_query
- NEVERGENERATE   = set a PasswordItem's .generate_option to :never_generate

For this example, if the answer to ItemB was 'answer1' the sequence of
configuration queries/actions would be:

1. ItemA
2. ItemB
3. ItemC
4. ItemD
5. ItemH

## NOTES

1. The CliSimpScenario data Item can be assumed to always be pre-set (i.e. no
   query required).
2. Other data Item values will be pre-set, if they exist in the hieradata YAML
   file corresponding to the scenario, or are passed into 'simp config' by
   file or command-line arguments.  For example, simp::options::ldap is
   present in the simp' and the 'simp_lite' scenarios hieradata files, and thus
   will be pre-set here.
3. Remember Item order matters, as Items have access to values from data Items
   earlier in the tree and use those values in their logic.
   For example, several Items require cli::network::hostname, which is
   set by CliNetworkHostname.
4. ActionItems do not ask the user for any input, but simply affect an action.
5. Since modifiers are parsed as part of a YAML key, they must appear before the ':'.
   (This looks weird, but the parser knows what to do with it.)
