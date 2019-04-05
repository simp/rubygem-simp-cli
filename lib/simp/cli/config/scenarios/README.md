* [GENERAL INFORMATION](#general-information)
  * [How YAML decision trees are used](#how-yaml-decision-trees-are-used)
* [SCENARIO ITEMS YAML FORMAT](#scenario-items-yaml-format)
* [GENERATED YAML FILE FORMAT](#generated-yaml-file-format)
  * [Item YAML Modifiers](#item-yaml-modifiers)
* [YAML DECISION TREE DESIGN](#yaml-decision-tree-design)
  * [Guidelines](#guidelines)
  * [Other considerations](#other-considerations)

# GENERAL INFORMATION

This is a bit complicated...(which means it is ripe for a rewrite).
The YAML files in this directory are used to generate YAML strings that
describe the decision trees appropriate for configuring particular SIMP
scenarios.  Specifically, each `<scenario>_items.yaml` specifies a sequence
of YAML fragments that, when combined, creates the scenario's configuration
decision tree YAML.  Each fragment (aka part) is comprised of a sequence of
Items, where

* Each Item is a data Item or an action Item
* A data Item is used to ascertain a value, which, in turn can be used
  as a branch point in the decision tree
* An action Items simply affects an action
* Any Item (including action Items) can use the value(s) from one or more
  data Items that precede it in the tree.

## How YAML decision trees are used

`simp config` loads in pre-set values for Items, builds the configuration
decision tree using any pre-set values, and then traverses the decision tree
(i.e., 'executes' the decision tree).  During traversal, when it reaches a data
Item for which a value does not exist and a query is allowed, it queries the
user for that value. When it reaches an action Item, it either immediately
executes that action, or pushes the action on to a queue, for deferred
execution after all data has been gathered.

The behavior of `simp config` when it reaches an Item is controlled by

* Global `simp config` configuration from the command line,  such as
  `--apply`, `--apply-with-questions`, `--force-defaults`,
  `--disable-queries`, and KEY=VALUE pairs
* Item settings hardcoded within the Item class, such as `silent`,
  `skip_query`, `skip_yaml`, `skip_apply`, `allow_user_apply`,
  `defer_apply`, and `generate_option`
* Item validation, which for hashed passwords is *different* when the
  password is read in from a user (plain text password) and read in
  from a file (hashed password)
* Item modifiers embedded in the YAML (see below)

These combinations can be difficult to understand, and even more
difficult to get to operate correctly, when `simp config` is called
with permutations of the global options above (all legitimate use
cases we have seen with end users).  So, when you create a tree,
test, test, and test again. What you don't test is very likely to
come back an bite you with a failure in the field.

# SCENARIO ITEMS YAML FORMAT

The scenario files are used to generate the YAML decision trees.  These
files must be named `<scenario>_items.yaml` and must contain 3 keys:

* name: Name of the scenario
* description: Description of the scenario
* includes: Sequence of YAML fragments (parts) that will be concatenated
  to create the scenario's configuration, decision tree YAML.

Any element in the 'includes' sequence can itself have 0 or more
variable substitutions defined. See `simp_item.yaml` and `parts/ldap_setup`
for an example of variable substitutions.

NOTE:

* Each part in the 'includes' must exist in the 'parts' sub-directory.
* Since many configuration Items have dependencies upon other Items, the
  parts must be listed in a fashion that satisfies these dependencies.
  Otherwise and Simp::Cli::Config::InternalError will be raised.
* Fragments are intended to provide a form of code reuse. So, apply
  the DRY principle, when you are creating/reworking scenarios.
* `spec/lib/simp/cli/config/items_yaml_generator_spec.rb` is the
  unit test for the scenario YAML file generator.

  - The test needs to be updated when a supported scenario changes.
  - The test **should** be updated when a scenario is added.
  - `spec/lib/simp/cli/config/files/*_generated_items_tree.yaml` contain
    the current YAML decision trees for the supported scenarios.
  - Working with this test is an easy way to debug parsing problems
    with the generated YAML file.

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
used to control specific behaviors of an Item.

For this example, if the answer to ItemB was 'answer1' the sequence of
configuration queries/actions would be:

1. ItemA
2. ItemB
3. ItemC pre-modified by modifier1
4. ItemD
5. ItemH


## Item YAML Modifiers

The behavior of each Item in the YAML decision tree can be modified by the
following modifiers:

* VALUE=value:

  Set the Item's .value to value, which effectively pre-sets the value
  and overrides any existing pre-set value. **Only** makes sense when
  used with SKIPQUERY and SILENT, because you are actually overriding
  a value the user has never been queried for. Ignored if the specified
  value is empty.

* FILE=value:

  Set the Item's .file to value, overriding the hardcoded value in the Item.
  Ignored if the specified value is empty.

* DRYRUNAPPLY:

  Make sure an ActionItem's apply() is called even when the `--dry-run``
  option is specified.

* NOAPPLY:

  Set an ActionItem's .skip_apply; ActionItem.apply() will do nothing

* USERAPPLY:

  Execute an ActionItem's apply() even when running as a non-privileged user

* IMMEDIATE:

  Execute an ActionItem's apply() immediately when the tree is traversed.
  Otherwise the Action's will be applied after all data has been gathered
  from the user

* SILENT:

  Set an Item's .silent. Suppresses stdout console/log output. This option
  is best used in conjuction with SKIPQUERY for Items for which no user
  interaction is required (i.e., Items for which internal logic should be
  used to figure out their correct values).

* SKIPQUERY:

  Set Item#skip_query to true. Item will use
  Item#default_value_noninteractive() for value.

* NOYAML:

  Set Item#skip_yaml to true. No YAML for Item will be written. Useful if
  you don't want to duplicate a value that matches the one found in the
  scenario YAML.

* GENERATENOQUERY:

  Set PasswordItem#generate_option to :generate_no_query.

* NEVERGENERATE:

  Set PasswordItem#generate_option to :never_generate.


# YAML DECISION TREE DESIGN

## Guidelines

The overriding design guidelines when writing a YAML decision tree are
as follows:

* Minimize the queries and logging to streamline/simplify the user experience.
  SIMP is very complicated to a new user!

  - Never ask the user for information that can be derived automatically.
    Instead, silently determine the value for the user.
  - Don't log information about automatically determined settings, as
    this is super confusing to the user. This should be true not only to
    `simp config` runs with full queries, but, if possible, runs using
    answers files for which there may be no queries at all.

* Don't write unnecessary settings to the output YAML files.

  - If a value matches the value set for scenario, don't repeat it.
  - If something has to be determined from the server each time `simp config`
    is run, don't persist it, or if you have to persist it, make sure the
    Item's description makes it clear it can't be modified by the user.
    (Already handled for Items for which SKIPQUERY (Item#skip_query == true)
    and SILENT (Item#silent == true) are both enabled). Otherwise, users
    are especially confused when they attempt to modify such a value in the
    answers file, feed the answers back into `simp config`, and have their
    perceived customization overwritten.

* Minimize use of action Items that have to be run immediately.  We want the
  user to be able to run through the query portion and then exit before the
  bulk of the actions are taken.  (Yes, they can use the `--dry-run`
  option, but are more likely to run through the program entering dummy
  information than to use that option, and then panic when the actions
  are applied.)

* When you create new Items for which you can detect user-input/system settings
  that may cause `simp bootstrap` to fail, log the problem in yellow and then
  write an entry in the bootstrap lock file. This will remind the user to verify
  the potential issue has been resolved before attempting `simp bootstrap`.

## Other considerations

There are bunch of 'oh-by-the-ways' that may not be obvious:

1. The CliSimpScenario data Item can be assumed to always be pre-set (i.e. no
   query required), but **must** be in the tree in order to set the value in the
   Puppet environment `site.pp` file.  It has to determined prior to generation
   of the tree, because it dictates which tree is generated.

2. Other data Item values will be pre-set, if they are passed into 'simp config'
   by file or command-line arguments.

3. When constructing the decision tree, the decision tree generator will
   automatically add an answers file writer (action Item) after each
   specified Item, to affect the safety-save.

4. The decision tree generator will always add to the end of the decision tree
   the final action Items to persist both the answers file and the Puppet
   environment hieradata file.

5. When using 'VALUE=value', you must ensure the value you provide can be
   transformed by the Item, as needed. For example, a YesNoItem can transform
   'yes' into true.

6. Remember **Item order matters**, because some Items have logic that depends
   upon the values of other Items, and the value of each Item is only guaranteed
   to be set when that Item is reached during decision tree traversal.

7. Action Items do not ask the user for any input, but simply affect an action.

8. Action Items, by default, are deferred until the entire tree is parsed. You
   must use the IMMEDIATE modifier to cause an action Item to execute when it
   is reached during traversal of the decision tree.

9. Since modifiers are parsed as part of a YAML key, they must appear before
   the ':'.  (This looks weird, but the parser knows what to do with it.)
