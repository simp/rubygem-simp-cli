# simp-cli

A cli interface to configure SIMP and simplify administrative tasks.

## Usage

```bash
simp COMMAND [OPTIONS]
```

**NOTE:** The `simp` cli command is intended to be run from a SIMP-managed OS.


### Commands
#### Configuration
##### `bootstrap`
Bootstraps a SIMP system (requires configuration data generated by `simp config`).</dd>

##### `config`
Creates SIMP configuration files with an interactive questionnaire.


#### Adminstration
##### `doc`
Displays SIMP documentation in elinks.

##### `passgen`
Controls user passwords.


#### Recently deprecated
##### `check` _(removed)_
Validates various subsystems

##### `cleancerts` _(deprecated - use `puppet cert clean CERTNAME` instead)_
Revokes and removed Puppet certificates from a list of hosts.

##### `runpuppet`_(deprecated - use [mcollective](http://puppetlabs.com/mcollective) instead._
Runs puppet on a list of hosts.


##### `puppeteval` _(deprecated - use `puppet agent --evaltrace` instead)_
Gathers metrics information on Puppet runs.


## License
See [LICENSE](LICENSE)
